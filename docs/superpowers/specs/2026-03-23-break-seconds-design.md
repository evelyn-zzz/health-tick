# 休息时长支持秒级设置 + 20-20-20 护眼模式

## 背景

20-20-20 护眼法则：每用眼 20 分钟，远眺 6 米外 20 秒。当前 HealthTick 休息时长最低 1 分钟，无法满足 20 秒的需求。

## 方案

两部分改动：
1. 将 `breakMinutes: Int` 改为 `breakSeconds: Int`，内部统一用秒存储
2. 新增 20-20-20 护眼模式开关，开启后锁定相关设置

## 改动清单

### 1. AppConfig（AppState.swift）

```swift
- var breakMinutes: Int = 2
+ var breakSeconds: Int = 120          // 默认 2 分钟 = 120 秒
+ var eyeCareMode: Bool = false        // 20-20-20 护眼模式
+ var savedWorkMinutes: Int = 60       // 护眼模式关闭时恢复用
+ var savedBreakSeconds: Int = 120     // 护眼模式关闭时恢复用
+ var savedBreakConfirm: Bool = true   // 护眼模式关闭时恢复用
```

### 2. 20-20-20 护眼模式逻辑（AppState.swift）

开启护眼模式时：
- 保存当前 `workMinutes`、`breakSeconds`、`breakConfirm` 到 saved 字段
- 锁定 `workMinutes = 20`、`breakSeconds = 20`、`breakConfirm = false`
- 每日目标不锁定，用户自行调整

关闭护眼模式时：
- 从 saved 字段恢复 `workMinutes`、`breakSeconds`、`breakConfirm`

### 3. SettingsView.swift — UI

护眼模式开关放在 **AppTab（计划 Tab）的每日目标滑块下方**：

```
工作时长    [====------] 40 分钟
休息时长    [==--------]  2 分钟
每日目标    [=====-----]  7 次
─────────────────────────────
👁 20-20-20 护眼模式   [开关]
  每 20 分钟远眺 20 秒，保护视力
```

开启后：
- 工作时长、休息时长滑块变为**禁用状态**（灰色，不可拖动），显示锁定值
- 每日目标滑块保持可用

休息时长滑块改造（护眼模式关闭时生效）：
- 范围：20 秒 ~ 15 分钟（即 20...900 秒）
- 显示格式化：
  - < 60 秒：显示 "20秒" / "20s"
  - ≥ 60 秒且整分钟：显示 "2分钟" / "2min"
  - ≥ 60 秒非整分钟：显示 "1分30秒" / "1m30s"
- 滑块步进：20~60 秒区间步进 10 秒，1~15 分钟区间步进 30 秒
- 使用离散值数组 + Slider 映射实现非线性步进

### 4. Database.swift — 配置持久化

- config 表 key 从 `break_minutes` 改为 `break_seconds`
- 默认值从 `"2"` 改为 `"120"`
- 新增 key：`eye_care_mode`、`saved_work_minutes`、`saved_break_seconds`、`saved_break_confirm`
- **迁移兼容**：加载时若发现旧 key `break_minutes`，自动转换为秒并写入新 key，删除旧 key

### 5. Database.swift — sessions 表

- sessions 表中 `break_minutes` 列保持不变（历史数据兼容），新记录写入时做 `breakSeconds / 60` 转换（取整，记录级精度够用）
- `startSession` 方法签名参数名改为 `breakSeconds`，内部 SQL 写入 `breakSeconds / 60`
- 导出数据保持 `break_minutes` 字段不变

### 6. AppState.swift — 计时逻辑

所有 `config.breakMinutes * 60` 替换为 `config.breakSeconds`：

- `startBreak()` 中 `let secs = config.breakSeconds`
- `startSession` 调用传 `breakSeconds: config.breakSeconds`
- 配置变更检测 `newConfig.breakSeconds != old.breakSeconds`

### 7. BreakOverlay.swift — 进度计算

```
- let total = state.config.breakMinutes * 60
+ let total = state.config.breakSeconds
```

### 8. OnboardingView.swift

- onboarding 中的休息时长设置同步适配秒级

### 9. Strings.swift — 本地化

```swift
static var unitSeconds: String { isZh ? "秒" : "s" }
static var eyeCareMode: String { isZh ? "20-20-20 护眼模式" : "20-20-20 Eye Care" }
static var eyeCareDesc: String { isZh ? "每 20 分钟远眺 20 秒，保护视力" : "Look 20 feet away for 20s every 20 min" }
```

### 10. 测试文件

- `test_time_logic.swift`、`test_streak.swift` 中的 sessions 插入保持 `break_minutes` 列不变（表结构未改）

## 数据迁移策略

用户升级后首次启动：
1. 读取 config 表，若存在 `break_minutes` key → 值 × 60 → 写入 `break_seconds` → 删除 `break_minutes`
2. 若已存在 `break_seconds` key → 无操作
3. sessions 表不迁移，保持 `break_minutes` 列

## 不改的部分

- sessions 表结构不动（避免迁移复杂度）
- 现有 UI 布局和交互流程不变
- 菜单栏倒计时显示格式已支持秒级（`formattedTime` 用 MM:SS）
