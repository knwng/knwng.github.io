#!/bin/bash

set -euxo pipefail

hexo clean && hexo g --deploy && hexo server

