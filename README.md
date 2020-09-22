# initialize-server
initialize-server是脚本管理程序，它用于配置Linux服务器的部分深度学习环境：如安装miniconda，配置conda镜像源，配置pip镜像源，初始化git-config，等等。

## Overview
initserv为入口程序。每一项环境安装任务抽象成一个target，由initserv程序的参数指定target文件。

initserv支持用户自定义添加新的target和target依赖，如配置proxychains， 安装PyTorch等。

## Usage
Clone this repository, and do the following commands.

```bash
cd initialize-server
./initserv user/default
```