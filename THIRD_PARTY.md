# 上游组件与源码

## 小狼毫 0.17.4

- 作者：RIME Developers。
- 许可：GPL-3.0，见 `licenses/Weasel-GPL-3.0.txt`；官方安装包同时包含其第三方组件许可。
- 原始发布：https://github.com/rime/weasel/releases/tag/0.17.4
- 对应源码和构建说明：https://github.com/rime/weasel/tree/0.17.4
- 本项目仅封装官方原始安装包，不修改其二进制。

## 雾凇拼音

- 作者：iDvel 及贡献者。
- 许可：GPL-3.0，见 `licenses/Rime-Ice-GPL-3.0.txt`。
- 固定提交：`da1fbe602e38f26db846fa10120ee64c2b0324c0`。
- 对应完整源码：https://github.com/iDvel/rime-ice/tree/da1fbe602e38f26db846fa10120ee64c2b0324c0
- 字典、Lua 和 OpenCC 文件保持上游内容，通过单独的 `.custom.yaml` 选择输入方案和外观。

具体下载地址和校验值见 `upstream.json`。安装包的 `config/` 内包含实际使用的词库和脚本源码，`sources/` 内包含本项目启动器和构建脚本。发布页同时提供构建所使用的上游源码归档。
