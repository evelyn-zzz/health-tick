import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.green.gradient.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "figure.walk")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HealthTick 使用指南")
                            .font(.title2.bold())
                        Text("久坐提醒 · 强制休息 · 习惯养成")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Core workflow
                sectionTitle("核心工作流程", icon: "arrow.triangle.2.circlepath", color: .green)

                VStack(alignment: .leading, spacing: 12) {
                    flowStep("1", "工作计时", "启动后自动开始工作倒计时（默认 60 分钟），菜单栏图标显示为行走人物。", color: .green)
                    flowStep("2", "休息提醒", "倒计时结束后弹出提醒，可设置是否需要手动确认。", color: .orange)
                    flowStep("3", "强制休息", "进入休息倒计时（默认 2 分钟），弹出休息窗口。如果检测到你仍在操作，倒计时会暂停，直到你真正离开。", color: .blue)
                    flowStep("4", "继续工作", "休息结束后确认回来，自动开始下一轮工作计时。", color: .purple)
                }

                Divider()

                // Features
                sectionTitle("功能说明", icon: "slider.horizontal.3", color: .blue)

                VStack(alignment: .leading, spacing: 10) {
                    featureItem("deskclock.fill", "工作时长", "每轮工作的倒计时时间，范围 1-120 分钟。")
                    featureItem("cup.and.saucer.fill", "休息时长", "每次休息的倒计时时间，范围 1-15 分钟。")
                    featureItem("target", "每日目标", "每天需要完成的休息次数，范围 1-20 次。达标后连续天数 +1。")
                    featureItem("rectangle.inset.filled", "休息窗口位置", "可选右上角、左上角、屏幕中央（悬浮）或全屏强制。")
                    featureItem("hand.raised.fill", "休息确认", "开启后，工作结束需手动确认才进入休息；关闭则自动进入休息倒计时。")
                    featureItem("speaker.wave.2.fill", "提醒声音", "工作结束时播放提示音。")
                    featureItem("ear.fill", "操作检测提示音", "休息期间检测到操作时播放提示音，提醒你停下来。")
                    featureItem("arrow.counterclockwise", "重置", "重新开始当前工作计时。")
                    featureItem("pause.fill", "暂停 / 继续", "暂停当前倒计时，恢复后从暂停处继续。")
                    featureItem("trash", "重置数据", "在设置 > 关于中可清除所有打卡记录（需三次确认）。")
                }

                Divider()

                // Break overlay
                sectionTitle("休息窗口", icon: "macwindow", color: .orange)

                VStack(alignment: .leading, spacing: 8) {
                    Text("休息期间会弹出一个提示窗口，显示倒计时和随机提醒语。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("**操作检测**：如果你在休息期间继续使用电脑（空闲时间 < 3 秒），倒计时会自动暂停，确保你真正休息了足够时间。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("**强制跳过**：连续快速点击休息窗口 3 次可以强制关闭（紧急情况使用）。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Badges
                sectionTitle("徽章激励体系", icon: "medal.fill", color: .yellow)

                Text("连续每天达标可解锁徽章。徽章只有获得后才会显示，保持神秘感！以下是完整的徽章列表：")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(allBadges.enumerated()), id: \.offset) { _, badge in
                        HStack(spacing: 10) {
                            Text(badge.icon)
                                .font(.system(size: 24))
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(badge.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(badge.desc)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Divider()

                // Tips
                sectionTitle("使用建议", icon: "lightbulb.fill", color: .green)

                VStack(alignment: .leading, spacing: 8) {
                    tipItem("推荐工作 45-60 分钟，休息 2-5 分钟，符合番茄工作法理念。")
                    tipItem("每日目标建议设为 6-8 次，对应 6-8 小时工作时间。")
                    tipItem("休息时离开座位走动、远眺窗外、做简单拉伸效果最佳。")
                    tipItem("连续达标的关键是坚持——即使忙碌的日子也尝试完成最低目标。")
                    tipItem("使用全屏强制模式可以最大程度确保你去休息。")
                }

                Divider()

                // Update
                sectionTitle("检查更新", icon: "arrow.down.circle.fill", color: .purple)

                Text("HealthTick 支持通过 GitHub Releases 自动检查更新。在设置 > 关于页面可以手动检查，也会在启动时自动检查。发现新版本后会提示下载。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 20)
            }
            .padding(32)
        }
        .frame(minWidth: 560, minHeight: 500)
    }

    private func sectionTitle(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
        }
    }

    private func flowStep(_ num: String, _ title: String, _ desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text(num)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.bold())
                Text(desc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func featureItem(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.bold())
                Text(desc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tipItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.green)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
