---
title: >-
  Python Multiprocessing: Another Reason to Use multiprocessing.Process Instead
  of os.fork
tags:
  - python
  - multi-process
categories:
  - tech
date: 2024-06-06 22:34:44
---


> This article is a translation by ChatGPT4o, check [this](https://zhuanlan.zhihu.com/p/612380673) out if you read Chinese.

# TL;DR
When you spawn processes with `multiprocessing.Process` and select `fork` as the start method, there are additional operations performed besides just invoking `os.fork`, such as invoking some after-fork hooks registered by other objects. You can't trigger these hooks if using `os.fork` directly, potentially leading to errors.

<!-- more -->

# Introduction
Recently, I dived a little bit into Python's multiprocessing module and was impressed by the limitation of it. 

I often heard that for multi-process programming, you should not use `os.fork` directly but use `multiprocessing.Process` instead. I never really understood why though. But some popular projects, such as Gunicorn, use `os.fork` to [spawn child processes](https://github.com/benoitc/gunicorn/blob/master/gunicorn/arbiter.py#L567).

I got some insights when solving [this problem](https://stackoverflow.com/questions/37692262/python-multiprocessing-assertionerror-can-only-join-a-child-process), which merely through exceptions during cleanup and does not impact the runtime.

However, during sick leave, I looked through issues on CPython repository tagged with "expert-multiprocessing" and found an [interesting issue](https://github.com/python/cpython/issues/101320), where using correct method to start subprocesses or not significantly impacts runtime.

# The Problem
In this issue, the author was trying to

1. create a `Manager` object in the main process;
2. create a `dict` in the `Manager` process which has a corresponding `DictProxy` object in the main process and is **initialized**;
3. manually serialize the `DictProxy`;
4. fork a child process and restore the `DictProxy` in the child process;
5. access to the dictionary concurrently from both processes.

Here's the code:

```python
import os
from multiprocessing.managers import SyncManager

if __name__ == '__main__':
    manager = SyncManager(authkey=b'test')
    manager.start()
    address = manager.address
    d = manager.dict()
    pickled_dict = d.__reduce__()
    pickled_dict[1][-1]["authkey"] = b"test"
    print(pickled_dict)
    for i in range(1000):
        d[i] = i

    child_id = os.fork()

    if child_id != 0:
        # in parent process
        # do something on the proxy object forever
        i = 0
        while True:
            d[i % 1000] = i % 3434
            i += 1
    else:
        # in child process

        # connect to manager process
        child_manager = SyncManager(address=address, authkey=b'test')
        child_manager.connect()

        # rebuild the dictionary proxy
        proxy_obj = pickled_dict[0](*pickled_dict[1])

        # read the proxy object forever
        while True:
            print(list(proxy_obj.values())[:10])
```

Running this code throws an exception: `_pickle.UnpicklingError: invalid load key, '\x0a'`.

The author also provided another code snippet, which didn't use the standard `dict` data type, instead, he registered a custom class to the `manager` and used locks in the member methods of this class. Then the code worked. At the beginning, this information seems useful, but it's proved to be quite confusing later.

```python
import os
from multiprocessing.managers import SyncManager
from threading import RLock

class SyncedDictionary:
    def __init__(self):
        # store the data in the instance
        self.data = {}
        self.lock = RLock()
        print(f"init from {os.getpid()}")

    def add(self, k, v):
        with self.lock:
            self.data[k] = v

    def get_values(self):
        with self.lock:
            return list(self.data.values())

if __name__ == '__main__':
    # custom class

    SyncManager.register("custom", SyncedDictionary)
    manager = SyncManager(authkey=b'test')
    manager.start()
    address = manager.address

    print(f"from main pid {os.getpid()}")
    custom_dict = manager.custom()
    pickled_dict = custom_dict.__reduce__()
    pickled_dict[1][-1]["authkey"] = b"test"
    print(pickled_dict)
    child_id = os.fork()

    if child_id != 0:
        # in parent, do work on the proxy object forever
        i = 0
        while True:
            custom_dict.add(i % 1000, i % 3434)
            i += 1
    else:

        for i in range(3):
            os.fork() # even more child processes...

        print(os.getpid())
        # in children
        # connect to manager process
        child_manager = SyncManager(address=address, authkey=b'test')
        child_manager.connect()

        # rebuild the dictionary proxy
        proxy_obj = pickled_dict[0](*pickled_dict[1])
        # read on the proxy object forever
        while True:
            list(proxy_obj.get_values())[:10]
```

# Background
## The Manager
In the `multiprocessing` module, users can create a `Manager` object in the main process, which will starts a new process(called the manager process), and keeps a proxy object in the main process.

The proxy communicates with the manager process via sockets (It's likely using pipes on Windows, but I haven't looked into it). Objects created through this proxy are actually created in the manager process. The proxy sends instructions to the manager process to control operations like creating objects and calling member methods.

Other processes can access this object by creating a proxy and connecting to the socket address the manager process is listening on. This design makes it convenient to share objects between different processes.

## Register Classes with Manager
The standard library has registered some classes ahead, such as `dict` and `Array`. Custom classes can also be registered using the [register](https://github.com/python/cpython/blob/14e1506a6d7056c38fbbc0797268dcf783f91243/Lib/multiprocessing/managers.py#L701) method. 

For more details, see the [multiprocessing — Process-based parallelism documentation](https://docs.python.org/3/library/multiprocessing.html), or better yet, check the source code: [multiprocessing/managers.py](https://github.com/python/cpython/blob/main/Lib/multiprocessing/managers.py).

# Conflicted Communication Stream
Based on the exception message, and after debugging, I found that the communication data streams of two processes with the manager process might be mixed, which failed the decoding.

As mentioned above, the proxy in the main process communicates with the manager process through socket to call methods. But how is this communication created?

The [`BaseProxy._callmethod`](https://github.com/python/cpython/blob/main/Lib/multiprocessing/managers.py#L811) method, which is used by the proxy to call methods, will first check if there's an existing connection in its TLS (Thread-Local Storage). If so, just reuse it; otherwise, it will invoke [`BaseProxy._connect`](https://github.com/python/cpython/blob/main/Lib/multiprocessing/managers.py#L802) to establish a new connection:
```python
def _connect(self):
    util.debug('making connection to manager')
    name = process.current_process().name
    if threading.current_thread().name != 'MainThread':
        name += '|' + threading.current_thread().name
    conn = self._Client(self._token.address, authkey=self._authkey)
    dispatch(conn, None, 'accept_connection', (name,))
    self._tls.connection = conn

def _callmethod(self, methodname, args=(), kwds={}):
    '''
    Try to call a method of the referent and return a copy of the result
    '''
    try:
        conn = self._tls.connection
    except AttributeError:
        util.debug('thread %r does not own a connection',
                   threading.current_thread().name)
        self._connect()
        conn = self._tls.connection

    conn.send((self._id, methodname, args, kwds))
    kind, result = conn.recv()
```

[This](https://github.com/python/cpython/blob/main/Lib/multiprocessing/managers.py#L761) describes how to reuse the connection in TLS:
```python
def __init__(self, token, serializer, manager=None, authkey=None, exposed=None, incref=True, manager_owned=False):
    with BaseProxy._mutex:
        tls_idset = BaseProxy._address_to_local.get(token.address, None)
        if tls_idset is None:
            tls_idset = util.ForkAwareLocal(), ProcessLocalSet()
            BaseProxy._address_to_local[token.address] = tls_idset
    self._tls = tls_idset[0]
```

We can see that `self._tls` is of type `util.ForkAwareLocal`, a subclass of `threading.local`, which is stored in TLS and defined as:
```python
class ForkAwareLocal(threading.local):
    def __init__(self):
        register_after_fork(self, lambda obj : obj.__dict__.clear())

    def __reduce__(self):
        return type(self), ()
```

During forking, the TLS data in parent process [is copied to the child process](https://stackoverflow.com/questions/60807085/does-data-stored-in-threading-local-get-passed-to-child-processes-started-with-p/60807086#60807086). If a connection has already been created before forking, both parent and child processes will communicate through the same socket, which causes conflicts.

# Why multiprocessing.Process works fine?
How does `multiprocessing.Process` avoid this problem?

Through the definition of `ForkAwareLocal`, we can see that it registers a lambda function (`lambda obj: obj.__dict__.clear()`) via `register_after_fork` in its constructor. This lambda function clears the object's `__dict__`, which stores attributes.

`register_after_fork` registers functions to a global registry named `_afterfork_registry`. And these functions are called sequentially in `_run_after_forkers`

```python
_afterfork_registry = weakref.WeakValueDictionary()
_afterfork_counter = itertools.count()

def _run_after_forkers():
    items = list(_afterfork_registry.items())
    items.sort()
    for (index, ident, func), obj in items:
        try:
            func(obj)
        except Exception as e:
            info('after forker raised exception %s', e)

def register_after_fork(obj, func):
    _afterfork_registry[(next(_afterfork_counter), id(obj), func)] = obj
```

To summarize, as long as we trigger the hook function registered by `ForkAwareLocal`(the lambda function) by calling `_run_after_forkers`, we can clear the attributes in `self._tls`. Then when we invoke `_callmethod`, it will raise `AttributeError` and prompt the proxy to create a new connection to the manager process. Then there will be no conflict since processes no long use the same connection now.

But who calls this `_run_after_forkers`? A global search indicates that it's in `BaseProcess._after_fork`. And `BaseProcess` is the superclass of `multiprocessing.Process`.
```python
@staticmethod
def _after_fork():
    from . import util
    util._finalizer_registry.clear()
    util._run_after_forkers()
```

If interested, you can dive deep. The entire invoke chain is:
- `multiprocessing.context.Process.start`
- `multiprocessing.process.BaseProcess.start`
- `multiprocessing.context.Process._Popen`
- `multiprocessing.context.ForkProcess._Popen`
- `multiprocessing.popen_fork.Popen._launch`
- `multiprocessing.process.BaseProcess._bootstrap`
- `multiprocessing.process.BaseProcess.after_fork`

Only when you use `multiprocessing.Process` to spawn a process, the attributes in `self._tls` can be cleared by the hook and conflicts can be avoided.

# Solutions
Knowing the cause, I prompted several solutions (all based on the author's first code snippet in the Github issue):

## 1. Manually update the connection
```python
proxy_obj = pickled_dict[0](*pickled_dict[1])
proxy_obj._connect() # create new conn
```

## 2. Manually call the hook function
```python
from multiprocessing.util import _run_after_forkers

pid = os.fork()

if pid == 0:
    # in child
    _run_after_forkers()
```

## Use `multiprocessing.Process` instead of `os.fork`
Just follow the documents. Note that the proxy objects can be passed to `Process` as parameters.

# Debugging Tips
You can use this snippet to set the multiprocessing internal logger's level to debug to print more information without modifying the source code:
```python
import logging
from multiprocessing.util import log_to_stderr

log_to_stderr(logging.DEBUG)
```

# PS
Why did I say the author's second example is somehow confusing?

Because the essential difference between the two code snippets is not that one uses a built-in type and the other a custom type. The key is that the first assigns values to the shared object before forking which generates a connection in TLS. The second does not assign values before forking. If you add an assignment before forking in the second snippet, you will get the same result:
```python
for i in range(1000):
    custom_dict.add(i, i) 
```

# Conclusion
Multi-process programming in Python is not a very pleasant thing to do, due to a lack of detailed documents and you have to dive into source code. Moreover, in order to avoid resource leaks, the `multiprocessing` module has many built-in hooks and additional processes to manage resources, which weakens developers' abilities to manage them precisely.
