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

## 更新记录

### v1.34

- **修复 P0：卸载过程可能毁掉原系统的引导配置。** `Uninstall-VHDSystem.ps1` 用 `-split "(?m)^-{20,}"` 把 `bcdedit /enum osloader /v` 的输出切成一个个启动项。但 bcdedit 的分隔线长度等于表头文字长度，`Windows Boot Loader` 是 19 个字符，于是这条正则永远匹配不上，整份输出成了唯一一块；随后「精确匹配」取的是这个块里第一个 `标识符`，也就是**物理机原系统**，而不是那个 VHD 条目。删掉它时连它的 `winresume` 一起消失，`{bootmgr}` 的 `default` / `displayorder` 元素也被一并移除，重启就停在 `0xc0000098`「引导配置数据文件不包含有效的操作系统信息」，连菜单都不给。
- 切块不再依赖横线长度：`Split-BcdEntries` 按 `标识符` / `identifier` 行切分（安装器和修复工具本来就是这么写的），切完还会自校验块数。块数和原文里标识符的个数对不上时，卸载直接中止，虚拟硬盘和启动项都不动。
- 按状态文件记录的 GUID 删除不再是盲删：逻辑别名（`{current}`、`{default}`、`{bootmgr}` 等）一律拒绝，并且先用 `bcdedit /enum <GUID> /v` 回读该条目的 `device`，和 `vhd=[X:]\路径\xxx.vhdx` 比对一致才删。
- 仅按文件名兜底不再删任何东西：两块盘各有一个同名 VHDX 时，只列出候选并请你人工确认。
- 删完会校验 `{bootmgr}` 的 `default` 是否仍指向一个真实可启动的条目，不是就改指过去；一个可启动条目都不剩时，用安装时导出的 BCD 备份还原。自检解析不可靠时，宁可完全不碰 BCD，也不猜。
- `$removed` 现在只在真正删除成功时计数。
- 新增回归测试 `src/build/test_bcd_parse.ps1`（24 条断言）：用真实形态的 19 横线输出分别跑新旧两套切块逻辑，旧逻辑一旦不再取到原系统 GUID 就会失败。
- 全部工具版本统一到 v1.34。



### v1.33

- **抽出共享模块 + 构建期内联**：`Say` 原本在每种语言的 5 个脚本里各有一份、一字不差。现在只在 `src/shared/zh-CN/Logging.ps1` 里定义一次；各脚本用 dot-source 引用，打包时由 `src/build/inline_shared.py` 把模块函数体直接拼进脚本。发布出去的 `.bat` 依旧是单个自解压文件，运行期不依赖任何外部文件，也没有 `Import-Module`。
- 构建现在会硬报错：共享模块缺失、dot-source 指向了另一种语言的目录、或内联后仍有残留引用，都会直接失败而不是静默产出。
- `verify_en.py` / `verify_zh.py` 增加断言：模块里定义的每个函数必须真的出现在解码后的载荷里。
- **无行为变更**：控制台文案、交互提示、退出码、日志输出与 v1.32 完全一致，这一版只是还代码债。
- 全部工具版本统一到 v1.33。

### v1.32

- **修好 BCD 非 ASCII 路径回读误判**：`chcp 437` 会让 `bcdedit` 把中文路径回显成 `?`，导致「写对了却被判成路径错」。现在允许非 ASCII 位置显示 `?`，不一致时再用 `bcdedit /export` 导出 hive 按 UTF-16 找路径二次确认。
- **提前写 provisional state**：在写启动项**之前**就先落一个 `.boot.txt` 标记，这样即使 BCD 坏到 `/copy`、`/create` 都拿不到 GUID，修复工具也能找到这块盘。
- **Repair 加最终校验**：删 vhdx 里的 ESP/MSR 之前，再核对一次磁盘 `Location` 与目标文件一致——同名不同目录的盘不再有被误删风险。
- **驱动工具「未添加」误报**：英文 `pnputil` 的成功提示是 *"Driver package added successfully"*，旧匹配串打不中。补上正确写法 + 驱动仓库兜底，并修掉一个 `$leaf` 先用后赋值的问题。
- **启动器 `.bat` 转发 `%*`**：`修复启动菜单.bat -VhdPath "…"` 现在能把参数传进去（含 UAC 提权跨越）。
- 全部工具版本统一到 v1.32。

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
