# 虚拟硬盘系统

**不用 U 盘、不改 BIOS、不进 PE，把 Windows 装成一个原生引导的 VHDX 系统。**

选一个 `.wim` / `.esd` / `.iso`，挑一个文件夹、起一个名字，点「开始安装」。
重启后开机菜单多出一项：选它进新系统，选原来那项回老系统。
不想要了运行卸载工具，像删掉一个大文件一样干净。

[English](README.md) · [使用说明](docs/USER-GUIDE.zh-CN.md) · [English guide](docs/USER-GUIDE.md)

---

## 为什么做这个

想在机器上再要一份 Windows（测试、打游戏、干净的工作环境），常规做法要 U 盘、要进 BIOS、要进 PE，还有格式化错盘的风险。这个工具在**运行中的系统里**就能做完：

1. 在指定分区创建一个动态扩展的 `.vhdx`
2. 在里面建**一个** NTFS 分区（native boot 的硬性要求），用 DISM 把镜像展开进去
3. 通过 BCD API 往活动 BCD 存储里加**一条** `device=vhd=[...]` 启动项
4. 完事 —— 原系统、原有启动项、原有文件一个都没动

新系统对 Windows 来说就是一块真硬盘：能装驱动、装软件、跑 Windows Update，用多少长多少。

## 功能

- **不用 U 盘 / BIOS / PE**，直接在现有系统里跑
- **可以装多个**，每个都是独立 vhdx，各有自己的名字和菜单项
- **名字和位置自己定**：`D:\VHD\Gaming`、`E:\Systems\Clean`，本地 NTFS 盘随便放
- **`.wim` / `.esd` / `.iso` 都支持**：ISO 自动挂载、取出里面的镜像、装完（即使失败）自动卸载
- **多版本镜像**：一个 `install.wim` 里有四个 Server 版本也能选，自动跳过不能装的 WinPE 索引
- **实时进度 + 看门狗**：DISM 输出写文件、主线程轮询；真卡死（10 分钟无输出且目标盘不增长）直接中止，不会无限等
- **可完整回退**：改 BCD 前先导出备份，卸载时把 `timeout` / `displaybootmenu` 还原成安装前的值
- **9 个急救工具**，对应真机上踩出来的坑：装完没菜单、菜单指向错文件、残留盘符、新系统缺驱动、任务管理器多出空 GPU、装到一半卡住

## 快速开始

1. 克隆或下载本仓库
2. 选语言：**`zh-CN/`**（中文）或 **`en/`**（English）
3. 双击 `开始.bat`（英文是 `Start.bat`）按序号选功能，或直接双击 `双击我-装系统.bat`
4. 通过 UAC，选镜像、选文件夹、起名字，点「开始安装」
5. 重启，在开机菜单里选你起的名字

要求：Windows 10 1607+ / Windows 11 x64、管理员权限、**本地固定硬盘**上的 NTFS 分区、剩余空间 ≥ 设定大小 + 5GB。

两条容易忽略的宿主前提：

- **只支持英文 / 中文 Windows。** `bcdedit` / `diskpart` 的输出是按文字解析的，只认这两种语言。启动项本身是用它们可机器读取的选项写的，但回读校验在德语、日语系统上会误判。
- **镜像必须是 x64。** x86 / ARM64 镜像能顺利装完，然后永远起不来；现在会在动手之前就拒绝。

> 系统镜像不在仓库里，需要自己准备 `.wim` / `.esd` / `.iso`。

## 仓库结构

```
.
├─ zh-CN/              中文发行版（双击 开始.bat）
│  ├─ 开始.bat
│  ├─ 双击我-装系统.bat        自解压：base64 → PowerShell
│  ├─ 双击我-卸载新系统.bat
│  ├─ README.txt / USER-GUIDE.md
│  └─ 急救工具/                9 个工具
├─ en/                 英文发行版（双击 Start.bat），结构同上
├─ docs/
│  ├─ USER-GUIDE.zh-CN.md      完整中文说明（含每一版的排障复盘）
│  └─ USER-GUIDE.md            English guide
└─ src/
   ├─ zh-CN/           11 个中文 PowerShell 源码
   ├─ en/              11 个英文 PowerShell 源码
   └─ build/           make_bat_en.py · make_bat_zh.py · verify_en.py
```

`.bat` 是**自解压外壳**，不是逻辑本体：每个 bat 把自己的 PowerShell 脚本以 base64 存进去，运行时用 `certutil` 解到 `%TEMP%`、校验字节数、再提权重跑。所以双击就能用、不用改执行策略 —— 也所以源码在 `src/` 里。

## 构建

```powershell
# 从 src/en/*.ps1 重新生成英文 bat
python src/build/make_bat_en.py

# 校验：纯 ASCII、CRLF、载荷与 ps1 逐字节一致
python src/build/verify_en.py

# 从 src/zh-CN/*.ps1 重新生成中文 bat（GBK 编码，非 ASCII）
python src/build/make_bat_zh.py
```

## 原理与踩过的坑

```
.iso ──Mount-DiskImage──► sources\install.wim / install.esd
创建 .vhdx ──► 挂载 ──► GPT + 一个 NTFS 分区 ──► dism /Apply-Image
            ──► 卸载 ──► bcdedit: device = vhd=[D:]\目录\名字.vhdx
```

四条用血换来的规则（说明书里都有完整复盘）：

1. **绝不在 vhdx 里建 ESP。** UEFI 固件只读物理盘上的 ESP，bcdboot 会报成功而菜单始终是空的（v1.3）
2. **绝不把 `\EFI\Microsoft\Boot\bcd` 当文件读写。** 运行中的系统握着它，写必撞共享冲突；改用 BCD API 操作活动存储（v1.5）
3. **写 `vhd=` 之前必须先卸载 vhdx。** 挂着写，bcdedit 会把 `vhd=[...]` 偷换成 `partition=X:`，条目永远进不去（v1.6）
4. **写完整相对路径。** 文件在 `D:\VirtualDisks\` 却写成 `vhd=[D:]\maimai.vhdx`，条目在、就是起不来（v1.13）

## 安全说明

- 需要管理员权限：要建分区、展开镜像、改启动存储
- 只**新增**启动项，不改不删别人的；卸载时把 `timeout` / `displaybootmenu` 还原
- 每次改动前先把 BCD 导出到 `<目录>-logs\bcd-backup-<时间>.bcd`
- v1.31 起**绝不删 `C:\Boot`**（那是 Windows 真正的引导目录）；`C:\EFI` 要同时满足三条才删：48 小时内创建、子目录只有 `Microsoft\Boot`、里面没有 `BCD` / `bootmgfw.efi`
- 已知限制：Legacy BIOS 直接拒绝；改过的镜像开 Secure Boot 会 `0xc0000428`；vhdx 与原系统同盘时共享那块盘的性能与故障风险

## 已验证

UEFI x64 真机（Windows 10 19041 / Windows 11 宿主），从 `.wim` 和 `.iso` 安装 Windows 10 / Windows Server 2022，盘根和子目录都试过。Legacy BIOS、RAID/Intel RST、改过镜像 + Secure Boot **未验证** —— 见[使用说明](docs/USER-GUIDE.zh-CN.md)。

## 许可

MIT，见 [LICENSE](LICENSE)。
