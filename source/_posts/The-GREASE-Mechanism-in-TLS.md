---
title: The GREASE Mechanism in TLS
tags:
- tls
- security
categories:
- tech
date: 2024-06-06 11:28:59
---

{% blockquote %}
This article is a translation by ChatGPT4o, check [this](https://zhuanlan.zhihu.com/p/343562875) out if you read Chinese.
{% endblockquote %}


A few days ago, while reading about JARM, a novel TLS server fingerprinting tool proposed by [Salesforce], I noticed they used a `choose_grease()` function when constructing the TLS ClientHello record, which drove me to look into this GREASE mechanism.

<!-- more -->

```python
# Randomly choose a grease value
def choose_grease():
    grease_list = [b"\x0a\x0a", b"\x1a\x1a", b"\x2a\x2a", b"\x3a\x3a", b"\x4a\x4a", b"\x5a\x5a", b"\x6a\x6a", b"\x7a\x7a", b"\x8a\x8a", b"\x9a\x9a", b"\xaa\xaa", b"\xba\xba", b"\xca\xca", b"\xda\xda", b"\xea\xea", b"\xfa\xfa"]
    return random.choice(grease_list)
```

# What is GREASE?
GREASE stands for Generate Random Extensions And Sustain Extensibility, which was formally defined in [RFC8701]. It's a special mechanism to mitigate the difficulty in extending the TLS protocol in the future.

For those familiar with TLS, you know that during the handshake phase, the client first sends a ClientHello record to the server, which includes supported TLS versions, CipherSuites types, and some extensions. If the server can process this, it returns a ServerHello record with the chosen CipherSuite and some extensions. For extensibility, some values for cipher and extension fields are reserved for future use. For example, [TLSv1.2] introduced AEAD-type ciphers.

Similarly, GREASE limits certain reserved values for these parameters, called GREASE values, which currently hold no meaning in the TLS protocol. For instance, GREASE values for CipherSuites and the Application-Layer Protocol Negotiation (ALPN) extension include:
```
{0x0A,0x0A}, {0x1A,0x1A}, {0x2A,0x2A}, {0x3A,0x3A}, {0x4A,0x4A}, {0x5A,0x5A}, {0x6A,0x6A}, {0x7A,0x7A}, {0x8A,0x8A}, {0x9A,0x9A}, {0xAA,0xAA}, {0xBA,0xBA}, {0xCA,0xCA}, {0xDA,0xDA}, {0xEA,0xEA}, {0xFA,0xFA}
```

The protocol specifies that when the client sends a ClientHello, it **may** select one or more GREASE values to be sent to the server.

> A client MAY select one or more GREASE cipher suite values and advertise them in the "cipher_suites" field.

If the client receives a record from the server (e.g. ServerHello, Certificate, EncryptedExtensions, etc.) containing a GREASE value, it **must** reject the record and close the connection.

> Clients MUST reject GREASE values when negotiated by the server. In particular, the client MUST fail the connection if a GREASE value appears in any of the following

Furthermore, when the server finds GREASE values in ClientHello:

1. It **must not** use these GREASE values for further negotiation and must treat them as ordinary reserved values.
2. It **must** ignore these values and use other available values in this field for negotiation.

> When processing a ClientHello, servers MUST NOT treat GREASE values differently from any unknown value. Servers MUST NOT negotiate any GREASE value when offered in a ClientHello. Servers MUST correctly ignore unknown values in a ClientHello and attempt to negotiate with one of the remaining parameters. (There may not be any known parameters remaining, in which case parameter negotiation will fail.)

This is a brilliant design, akin to a prisoner’s dilemma. Every TLS library could be used both as a client or as a server. Given that there are several popular TLS libraries, there's a great chance that the libraries used by the client and the server are different, which forces them to agree on this convention.

Similarly, for parameters initially sent by the server, the RFC stipulates the behavior of the client and server.

# Why do we need GREASE?
One might wonder: if we want to reserve these values in the protocol, why don't we just write them down in the protocol?

This mechanism is based on practical considerations. Although RFCs are well-known and authoritative, they are merely standards made by the community. To be used in practice, they need to be implemented in libraries (such as OpenSSL, BoringSSL, etc.). In this conversion, the logic may deviate from the designer's intent. This can cause significant problems for foundational network protocols deployed on a large scale, e.g. TLS.

In the case of TLS, if we don't have GREASE to constrain the implementations, libraries may only support the values in the current protocol and throw exceptions for unknown values.

Although this implementation may work perfectly with the current protocol, when the IETF decides to upgrade it to have more CipherSuites values, libraries of newer protocol may fail to interact with older ones, hindering the deployment of the new protocol.

It's worth mentioning that GREASE values were initially set for the Version parameter, but it was removed in the final RFC.

> The values allocated above are thus no longer available for use as TLS or DTLS \[RFC6347\] version numbers.

Therefore, in TLSv1.3, they have to use `supported_versions` extension to indicate the support for TLSv1.3, instead of using Version parameter, so that they can be compliant with TLSv1.2. For more details, see this Cloudflare [blog].

# Conclusion
In a large-scale system like the Internet, changes are difficult and always take a long time. The deployment and upgrade of foundational network protocols are among these challenges. Many protocols seem straightforward at first glances, but you can learn something when you dive deep.

<!-- # References -->
[Salesforce]: https://engineering.salesforce.com/easily-identify-malicious-servers-on-the-internet-with-jarm-e095edac525a
[RFC8701]: https://tools.ietf.org/html/rfc8701
[TLSv1.2]: https://tools.ietf.org/html/rfc5246
[blog]: https://blog.cloudflare.com/why-tls-1-3-isnt-in-browsers-yet/
