# AIVM 通用规划约束

本文件是 AIVM 全部 Phase 的长期稳定约束来源。任何单步执行都必须把本文件作为完整上下文的一部分。

## 结论

AIVM 是一个原生 macOS Linux VM MVP：基于 Apple Virtualization.framework，在 Apple silicon Mac 上完成一台 ARM64 Linux VM 的创建、安装、启动、持久化、联网和删除闭环。

## 产品/项目目标

- 交付一个范围克制的原生 macOS 应用，而不是通用虚拟机平台。
- 首版只支持一台本地 Linux VM，完成从 ISO 安装到重复启动的闭环。
- 用户可见文案必须同时提供简体中文、英语、日语三种地道表达，并保持短句、动作导向、发布可用。

## 非目标

- 不做多 VM 管理、快照、克隆、回滚或云同步。
- 不做 bridged networking、自定义网络拓扑或端口转发 UI。
- 不做共享目录、剪贴板共享、USB 透传、音频、Rosetta for Linux。
- 不做 Intel Mac 支持、跨架构仿真、自动下载镜像、无人值守安装。
- 不导入 qcow2、vmdk 或其他第三方磁盘格式。

## 硬性工程约束

### 平台与工具链

- 产品目标平台为 Apple silicon Mac，macOS 14 及以上。
- Guest 镜像只承诺 ARM64 Linux；主验收镜像为 Ubuntu Desktop ARM64 LTS。
- 实现必须使用 Swift、SwiftUI/AppKit、Foundation、OSLog、XCTest 和 Apple Virtualization.framework。
- VM 运行底座必须使用 `VZVirtualMachineConfiguration`、`VZGenericPlatformConfiguration`、`VZEFIBootLoader`、`VZVirtualMachine`、`VZVirtualMachineView`。
- 必须启用 `com.apple.security.virtualization` entitlement。
- 不得要求 `com.apple.vm.networking` entitlement；MVP 只使用 NAT。

### 依赖边界

禁止引入以下内容：

- QEMU、UTM、Parallels、VMware 或其他虚拟化运行底座。
- 第三方 VM 管理守护进程、guest agent 依赖或后台常驻服务。
- 需要云端账号、远端同步或外部服务才能完成 MVP 主路径的依赖。

允许使用的仅限：

- Apple 平台 SDK 与系统框架。
- XCTest 和本仓库内脚本化审计工具。
- 后续 phase 明确接入且能被 required checks 证明的构建辅助文件。

### 数据与状态

- 每台 VM 使用 `~/Library/Application Support/phas/VMs/<vm-id>.vmbundle/` 作为 bundle 根目录。
- VM 元数据必须包含 schema version、稳定 VM ID、启动源、网络模式和状态。
- 虚拟磁盘优先采用稀疏分配策略。
- 删除 VM 时只能清理对应 bundle，不得触碰宿主机其他目录。
- 安装完成判定不得依赖 guest agent 或读取 guest 内部文件。

### 状态机与恢复

- 支持且只支持 `Draft`、`Installing`、`Stopped`、`Running`、`Error` 五个产品状态。
- 每个状态暴露的用户动作必须与 PRD 的动作权限一致。
- `Error` 是可恢复处置状态，不等于销毁 VM 数据。
- ISO 失效、空间不足、配置非法、启动失败、安装中断、状态不可信，都必须映射到用户可执行动作。

### 国际化与产品文案

- 所有用户可见字符串必须来自同一套本地化资源，覆盖 `zh-Hans`、`en`、`ja`。
- 三种语言必须是面向真实应用的短文案，不得出现机器翻译腔。
- 文案必须避免过程语言和内部术语，例如 `phase`、`执行阶段`、`流程进行中`、`step`、`process`、`ステップ`、`処理中`。
- 按钮和错误恢复文案必须指向动作，例如重新选择 ISO、释放空间后重试、查看日志、删除虚拟机。
- 不得把底层异常、API 类型名或调试栈直接展示给普通用户。

### 可观测性与隐私

- 关键生命周期事件必须写入本地日志：创建、启动、停止、失败、删除、状态迁移。
- 日志至少包含时间戳、VM ID、状态、启动源、错误摘要、应用版本、宿主机系统版本。
- 日志默认只保存在本机，不自动上传。
- 不记录 guest 屏幕内容、用户键盘输入、guest 内部文件内容。
- MVP 至少提供打开日志目录或导出诊断信息的本地入口。

## 质量底线

- 每个 phase 必须通过 `ruby scripts/planctl lint-contracts --phase <phase-id>`。
- 当前 phase 的 manifest required checks 全部通过前，不得运行 `complete`。
- 新增生产组件必须有真实调用点、激活条件、fallback 和运行证据。
- 新增用户可见字符串必须通过三语言 key 一致性审计。
- README 保持概括性；实现细节、验收矩阵和操作细则放入内部文档或 phase 产物并用链接引用。
