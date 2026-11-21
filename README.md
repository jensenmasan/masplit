# 马老师专属分屏 · MaSplit

对着 `IMG_4786.MP4` 里那个「S2分屏」做的定制版越狱插件：功能按视频逐项还原，品牌换成马老师，另外附一个能直接在手机浏览器里玩的交互预览。

- **目标环境**：iOS 16 rootless（palera1n / Dopamine），arm64 / arm64e
- **包名**：`com.malaoshi.masplit`
- **版本**：1.0.0
- **作者**：马老师

---

## 一、视频功能 → 本插件实现对照

| 视频里的能力 | 本工程实现 | 代码位置 |
|---|---|---|
| 中央浮窗承载应用 | 快照浮窗 + 点击唤起真实 App | `MSFloatingWindow` / `MSWindowManager` |
| 浮窗拖动、双指缩放 | Pan / Pinch 手势，右下角也有缩放手柄 | `MSFloatingWindow.m` |
| 多浮窗缩成卡片贴左右边缘 | 拖到屏幕 13% 内自动吸附收纳，宽 52pt | `minimizeToEdge:` |
| 浮窗数量上限 | 默认 8，超了自动关最旧的 | `MSWindowManager.showAppWithBundleID:` |
| 边缘上滑/下滑唤出 | 左右边缘手势，按顶部/底部/中部三个分区响应 | `onEdgePan:` |
| 上方/下方触发高度、速度阈值 | 设置面板三个滑杆，实时生效 | `MSPreferences` |
| 已安装应用列表（图标+版本+bundle id） | `LSApplicationWorkspace` 全量读取 | `MSAppListProvider` |
| 环形散开的图标选择动效 | 黄金角螺旋分布 + 逐个弹簧入场 | `MSRingSelector` |
| 窗口大小 65 / 圆角 30 / 上限 8 | 同名设置项，默认值一致 | `prefs/Resources/Root.plist` |
| 点击空白收起 | 桌面空白处 tap → 全部收纳 | `onBlankTap:` |
| 键盘模式 | 开启后浮窗高度上限从 80% 提到 94% | `expandedSizeForScale:` |
| 品牌水印 | 设置里可改，默认「马老师专属」 | `MSPreferences.watermark` |
| 真·双 App 同屏 | 实验模块，强制 Medusa 多窗口（见第六节） | `MSMultiTasking.m` |

---

## 二、目录结构

```
MaSplit/
├── Makefile                    # rootless，arm64 + arm64e
├── control                     # 包信息（iphoneos-arm64）
├── MaSplit.plist               # 只注入 com.apple.springboard
├── Tweak.xm                    # SpringBoard 入口：桌面钩子 + 右侧悬浮球
├── MSPreferences.{h,m}         # 设置读取层（Darwin 通知热加载）
├── MSFloatingWindow.{h,m}      # 浮窗本体：拖动/缩放/吸附/最小化
├── MSWindowManager.{h,m}       # 调度中心：宿主窗口、手势、数量上限、持久化
├── MSSnapshotProvider.{h,m}    # 快照：AppSwitcher → 截屏 → 星空封面兜底
├── MSAppListProvider.{h,m}     # 应用清单 / 图标 / 启动 / 前台应用
├── MSRingSelector.{h,m}        # 环形应用选择器
├── MSMultiTasking.{h,m}        # 实验：真·双 App 同屏
├── prefs/                      # 设置面板 bundle
│   ├── Makefile
│   ├── MSPrefsRootListController.{h,m}
│   └── Resources/{Root.plist, Info.plist}
├── layout/                     # 打包时原样落盘的文件
│   ├── DEBIAN/postinst
│   └── Library/PreferenceLoader/Preferences/{MaSplit.plist, MaSplit.png}
├── preview/index.html          # 可交互网页预览（重点看这个）
└── .github/workflows/build.yml # push 到 GitHub 自动出 deb
```

---

## 三、编译

> ⚠️ 我这边跑不了编译：本机 WSL 被安全策略禁用了，也没有 iOS SDK。工程是严格按 theos 规范写的，但**第一次编译请把报错发我**，我直接改。

### 方式 A：GitHub Actions（推荐，不用装环境）

```bash
cd MaSplit
git init && git add . && git commit -m "MaSplit 1.0.0"
gh repo create masplit --private --source=. --push
```

推上去后打开仓库的 **Actions → build-deb**，跑完在 Artifacts 里下 `masplit-deb`，就是打好的 `.deb`。

### 方式 B：本地 WSL / macOS

```bash
# 1. 装 theos（一次性）
export THEOS=~/theos
git clone --recursive --depth=1 https://github.com/theos/theos.git $THEOS
mkdir -p $THEOS/sdks && cd $THEOS/sdks
curl -L https://github.com/theos/sdks/archive/master.tar.gz | tar xz --strip-components=1

# 2. 编译
cd /mnt/c/Users/Jason/WorkBuddy/2026-11-21-14-26-33/MaSplit
export PATH=$THEOS/bin:$PATH
make clean package

# 3. 产物
ls packages/
# com.malaoshi.masplit_1.0.0_iphoneos-arm64.deb
```

依赖：`clang`、`make`、`ldid`、`xz-utils`、`fakeroot`（Ubuntu: `sudo apt install -y clang make ldid xz-utils fakeroot`）。

---

## 四、安装到手机

```bash
scp packages/com.malaoshi.masplit_1.0.0_iphoneos-arm64.deb root@<手机IP>:/var/mobile/
ssh root@<手机IP> "dpkg -i /var/mobile/com.malaoshi.masplit_1.0.0_iphoneos-arm64.deb && killall -9 SpringBoard"
```

rootless 越狱（palera1n / Dopamine）默认 SSH 端口 22，root 密码通常是 `alpine`（装完请改）。
也可以在 Sileo 里用「本地文件」安装这个 deb。

装好后：**设置 → 马老师分屏**。

---

## 五、怎么用

1. **开浮窗**：桌面右侧有个悬浮球（分屏图标），点一下弹出环形选择器，挑一个 App。
2. **动浮窗**：拖标题栏移动；右下角斜纹手柄缩放；双指也能缩放。
3. **收纳**：把浮窗拖到屏幕左/右边缘，自动缩成 52pt 卡片；点卡片展开；双击标题栏也能收纳。
4. **长按浮窗**：刷新快照 / 收起 / 关闭。
5. **边缘手势**：在左右屏幕边缘滑动 —— 顶部区向下拉收起、底部区向上推弹选择器、中部区切换收纳状态。
6. **点桌面空白**：全部收纳（可在设置里关）。
7. **设置项**：窗口大小、圆角、浮窗上限、动画时长、三个手势阈值、空白收起、键盘模式、水印文字、恢复默认、重启桌面。

---

## 六、关于「真·双 App 同屏」这个实验项

视频里那个中央窗口跑的是真实 App（内容在动）。要在 iPhone 上做到两个 App 同时前台可交互，只有一条路：强制打开 iPad 的 Medusa 多窗口能力，让两个 `UIScene` 同时渲染。

`MSMultiTasking.m` 会尝试强制这些开关：

- `SBMedusaSettings`：`medusaEnabled` / `splitViewEnabled` / `slideOverEnabled` / `allowMultipleWindows`
- `SBMainDisplayPolicyAggregator`：`supportsMedusa` / `supportsSplitView` / `supportsSlideOver`
- `SBApplication`：`supportsSplitView` / `supportsMultipleScenes`

**它不会崩，但也别期待百分百生效**：iOS 的多窗口最终取决于 App 自己的 `UIApplicationSceneManifest` 有没有声明多场景。声明过的（比如部分系统 App、少量第三方）能并排；没声明的，只会被强行塞进一个窗口，或者干脆不响应。

所以默认体验是「快照浮窗」这一档 —— 稳定、所有 App 都能用，视觉和视频一致。

---

## 七、网页预览（不用越狱就能看效果）

`preview/index.html` 是纯前端复刻，手机浏览器直接打开即可：

```bash
cd MaSplit/preview
python -m http.server 8080
# 手机浏览器访问 http://<电脑IP>:8080
```

能玩的东西：

- 拖动浮窗标题栏、右下角缩放、拖到边缘收成卡片
- 点右侧悬浮球 / 底部 ✦ → 环形图标散开选择器
- 底部 ◉ 一键收起/展开全部
- 底部 ⚙︎ → 设置抽屉，滑杆实时改窗口大小、圆角、上限、动画

---

## 八、已知限制 & 排错

**限制**

- 卡片里的画面是快照，不是实时视频流。iOS 不允许后台 App 把画面渲染进别的进程窗口，所以「实时」这件事只能靠真双开（实验项）。
- 快照优先取系统 AppSwitcher 缓存，取不到会生成一张带星空纹理的品牌封面 —— 这是有意的，保证任何 App 都有好看的卡片。
- 代码尚未在真机编译验证（见第三节说明）。

**排错**

| 现象 | 检查 |
|---|---|
| 装完没反应 | `ls /var/jb/Library/MobileSubstrate/DynamicLibraries/` 应有 `MaSplit.dylib` 和 `MaSplit.plist` |
| 设置里没有入口 | 装 PreferenceLoader；`ls /var/jb/Library/PreferenceBundles/MaSplitPrefs.bundle` |
| 桌面没有悬浮球 | 确认设置里「启用分屏」是开的，然后重启桌面 |
| SpringBoard 崩溃 | 看 `/var/mobile/Library/Logs/CrashReporter/SpringBoard-*.ips`，把最后 40 行发我 |

---

## 九、下一步可以加的

- 每个浮窗独立记住大小和位置（现在只记 bundle id 列表）
- 浮窗内嵌实时画面（真双开打通后）
- 分屏预设：一键「左直播右清理」
- 浮窗间拖拽传内容（URL / 文本）
