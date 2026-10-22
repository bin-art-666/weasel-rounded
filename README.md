# 小狼毫 · 通透圆角版

一套配置好的 Windows 中文输入法：小狼毫 + 雾凇全拼 + 通透大圆角候选框。

**[下载安装包](https://github.com/bin-art-666/weasel-rounded/releases/latest)** · [构建方法](#从源码构建)

## 外观和输入方案

- 只启用雾凇全拼，支持英文候选和中英混输。
- 横排 9 个候选词，数字键 1–9 选词。
- 候选框圆角 24，选中项圆角 16，蓝色选中背景。
- 背景不透明度约 85%，候选间距 14，左右留白 12。
- 只提供这套外观的浅色、深色变体，随系统切换。

背景为半透明，不包含实时背景模糊或液态玻璃折射。

## 安装与使用

1. 在 [Releases](https://github.com/bin-art-666/weasel-rounded/releases) 下载 `Weasel-Rounded-Setup.exe`。
2. 双击运行，点击“安装”。全新安装时允许官方小狼毫安装程序的管理员授权。
3. 等待词库编译完成，按 **Win + 空格** 切换到“小狼毫”。**Shift** 切换中英文。

安装包内置所需文件，安装时无需联网。适用于 Windows 10/11，使用系统自带的 .NET Framework 和 Windows PowerShell 5.1。建议在本人管理员账户下运行。

已有小狼毫时复用现有程序并应用配置，本项目当前以小狼毫 0.17.4 验证。其他版本尚未逐一测试。

安装前会把将被替换的文件备份到用户 Rime 目录旁的 `Rime-backup-时间` 文件夹。个人学习数据库和已有 `custom_phrase.txt` 保留。原有其他方案文件不会删除，但启用列表只保留雾凇全拼。

若需要恢复，退出小狼毫后把备份文件复制回原来的 Rime 用户目录，再运行“重新部署”。卸载输入法使用 Windows 设置中的“小狼毫”卸载项。

安装包没有数字签名，Windows 可能显示“未知发布者”。每次发布提供 `SHA256.txt` 供校验。

## 从源码构建

需要 64 位 Windows、.NET Framework 自带的 C# 编译器以及 PowerShell 5.1 或更新版本。无需先安装小狼毫。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

构建会下载 `upstream.json` 固定版本的官方小狼毫安装包和雾凇源码，并检查 SHA256。产物位于 `dist/`。上游安装包保持原样，项目中的启动器负责校验、备份、配置复制和部署。

```powershell
# 检查完整性、配置安装、备份、个人数据保留和损坏文件拦截
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1
```

测试只操作 `build/tests/` 下的模拟用户目录，不会安装或修改当前系统的输入法。仓库初始版本通过本机隔离测试；尚未在全新 Windows 虚拟机上验证完整首次安装流程。

## 文件结构

| 路径 | 内容 |
| --- | --- |
| `config/` | 唯一启用方案和圆角主题配置 |
| `src/RoundedWeaselSetup.cs` | 安装界面及解压启动器 |
| `src/install.ps1` | 校验、备份和部署逻辑 |
| `scripts/build.ps1` | 固定上游版本的构建脚本 |
| `scripts/test.ps1` | 不修改系统的安装测试 |
| `upstream.json` | 上游版本、来源和 SHA256 |

仓库及发布包不包含个人输入记录、用户学习数据库或本机备份。

## 开源说明

本项目按 [GPL-3.0](LICENSE) 提供，是个人配置整合项目，与上游官方发行版无隶属关系。

- [小狼毫 / Weasel](https://github.com/rime/weasel/tree/0.17.4)：RIME Developers，GPL-3.0；官方二进制安装包不作修改。
- [雾凇拼音 / rime-ice](https://github.com/iDvel/rime-ice/tree/da1fbe602e38f26db846fa10120ee64c2b0324c0)：iDvel 及贡献者，GPL-3.0。

源码、固定上游来源及各自许可见本仓库和 [THIRD_PARTY.md](THIRD_PARTY.md)。安装包也内置本项目安装器源码、配置和相关许可证。
