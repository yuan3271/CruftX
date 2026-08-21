# CruftX 1.2.1 更新说明

## 改进

- **垃圾搜索优化**：日常垃圾、卸载残留、回收站与已安装应用的搜索改为分词匹配，支持多个关键词任意顺序组合（如「微信 图片」），匹配更精准；搜索键预计算，输入时不再反复构建文本，界面更跟手
- **修复权限不足问题**：部分目录（如「容器」「组容器」及受保护的应用数据）在未授予「完全磁盘访问权限」时会无法读取，此前会被静默跳过。现在扫描后会自动检测并明确提示，并提供一键前往系统设置授权的入口；清理/卸载时也能区分「权限不足」与「文件正被占用」，给出准确原因

## 安装 / 升级

- 下载 `CruftX-1.2.1.dmg`，打开后拖入 Applications 文件夹
- 直接覆盖旧版本即可，设置与回收站数据会保留

---

# CruftX 1.2.1 Release Notes

## Improvements

- **Smarter junk search**: Daily junk, residue, Recycle Bin and installed-app search now use token matching, so multi-keyword queries work in any order (e.g. "WeChat images"); search keys are pre-computed so typing stays responsive
- **Fixed insufficient-permission issue**: some directories (e.g. Containers, Group Containers and protected app data) were silently skipped when CruftX lacks Full Disk Access. The app now detects them after a scan, explains the problem and offers a one-click link to grant access; cleanup/uninstall also distinguishes "permission denied" from "file in use" with an accurate message

## Install / Upgrade

- Download `CruftX-1.2.1.dmg`, open it and drag CruftX into Applications
- Replacing an older version keeps your settings and Recycle Bin data

---

# CruftX 1.2.0 更新说明

## 新增

- **办公专清并入日常清理**：微信、企业微信、QQ、钉钉、飞书、腾讯会议的缓存直接在「日常垃圾」中扫描与清理，侧边栏不再有单独的「办公专清」入口；聊天记录数据库（db_storage）依旧永不扫描
- **双视图浏览**：日常垃圾可切换「按分类 / 按应用」，自动从路径推断归属软件（如 `com.google.Chrome` → Google Chrome），无法归属的内容归入「系统 / 其他」
- **清理风险标注**：每项内容标注 低 / 中 / 高风险，列表行、分组头、概览页均有颜色徽标与说明
- **卸载残留容器扫描**：新增 `~/Library/Containers` 与 `Group Containers` 残留检测（仅匹配包名格式，默认不勾选）
- **回收站搜索**：可按键名或原路径搜索回收站内容

## 改进

- **默认只清理低风险内容**：缓存、日志、临时文件与办公软件的可重建缓存默认勾选；诊断报告、派生数据、图片/视频缓存默认不勾选，卸载残留全部默认不勾选
- **卸载残留误删防护**：跳过通用系统名称与近期仍在写入的目录；对已安装应用增加包名前缀与显著词重叠匹配（如已装「Tencent Lemon」不再把旧目录 `com.tencent.LemonMonitor` 误判为残留）
- **垃圾搜索强化**：日常垃圾与卸载残留可按名称、路径、应用名、类型搜索，卸载应用页支持按显示名（如「微信」）搜索
- **概览页重做**：新首页含扫描进度环、涉及应用与高风险统计、风险概览卡片、各分类进度条与快捷跳转
- **应用图标精修**：重绘为 Apple 风格 squircle，渐变更细腻，星芒带光晕与层次
- 中英文界面新增全部新文案

## 安装 / 升级

- 下载 `CruftX-1.2.0.dmg`，打开后拖入 Applications 文件夹
- 直接覆盖旧版本即可，设置与回收站数据会保留

## 注意

- 卸载残留与中高风险内容清理前请逐项确认
- 所有清理均可恢复（系统废纸篓或 CruftX 回收站）

---

# CruftX 1.2.0 Release Notes

## New

- **Office clean merged into Daily Junk**: WeChat, WeCom, QQ, DingTalk, Feishu and Tencent Meeting caches are scanned and cleaned from “Daily Junk”; no separate sidebar entry. Chat databases (db_storage) are still never touched
- **Two cleanup views**: Daily Junk can switch between “By Category” and “By App”, inferring the app from paths (e.g. `com.google.Chrome` → Google Chrome); unrecognized items go under “System / Other”
- **Risk labels**: every item is marked Low / Medium / High risk with colored badges and descriptions in lists, headers and the Overview
- **Container residue scan**: new detection in `~/Library/Containers` and `Group Containers` (bundle-ID names only, unchecked by default)
- **Recycle Bin search**: filter entries by name or original path

## Improvements

- **Default to low-risk cleanup only**: caches, logs, temp files and regenerable office caches are checked by default; diagnostics, derived data and image/video caches are not; all residue is unchecked
- **Residue false-positive protection**: skips generic system names and recently modified folders; added bundle-ID prefix and significant-token matching against installed apps (e.g. installed “Tencent Lemon” no longer flags old `com.tencent.LemonMonitor` folders)
- **Stronger search**: Daily Junk and Residue search by name, path, app and type; Uninstall search also matches display names (e.g. “微信”)
- **Redesigned Overview**: scan ring, involved-app and high-risk stats, risk overview cards, per-category progress bars and quick navigation
- **Refined app icon**: redrawn as an Apple-style squircle with richer gradients and a glowing sparkle cluster
- Full bilingual copy for all new strings

## Install / Upgrade

- Download `CruftX-1.2.0.dmg`, open it and drag CruftX into Applications
- Replacing an older version keeps your settings and Recycle Bin data

## Notes

- Review residue and medium/high-risk items before cleaning
- Every cleanup is recoverable (system Trash or CruftX Recycle Bin)
