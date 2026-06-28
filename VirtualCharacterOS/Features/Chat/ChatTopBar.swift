import SwiftUI

/// 聊天页顶部导航栏。显示角色名 + 副标题，右侧设置入口。
struct ChatTopBar: View {
    let characterName: String
    let subtitle: String
    let onSettingsTap: () -> Void
    let onBranchTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：分支切换入口
            if let onBranchTap {
                Button(action: onBranchTap) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                }
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }

            Spacer()

            // 中间：角色名 + 副标题
            VStack(spacing: 2) {
                Text(characterName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 右侧：设置入口
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
