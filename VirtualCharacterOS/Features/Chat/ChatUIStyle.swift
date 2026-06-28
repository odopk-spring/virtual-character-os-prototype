import SwiftUI

/// 聊天页面视觉常量集中管理。
enum ChatUIStyle {
    // MARK: - Colors

    /// 聊天背景色 #EDEDED
    static let chatBackground = Color(red: 237/255, green: 237/255, blue: 237/255)

    /// 输入栏背景 #F7F7F7
    static let inputBarBackground = Color(red: 247/255, green: 247/255, blue: 247/255)

    /// 分隔线 #D8D8D8
    static let hairlineColor = Color(red: 216/255, green: 216/255, blue: 216/255)

    /// assistant 气泡白
    static let assistantBubble = Color.white

    /// user 气泡绿 #95EC69
    static let userBubble = Color(red: 149/255, green: 236/255, blue: 105/255)

    /// 气泡文本色
    static let bubbleText = Color(red: 17/255, green: 17/255, blue: 17/255)

    /// 时间戳灰 #A8A8A8
    static let timestampGray = Color(red: 168/255, green: 168/255, blue: 168/255)

    // MARK: - Metrics

    /// 页面水平边距
    static let pageHorizontalPadding: CGFloat = 12

    /// 头像尺寸
    static let avatarSize: CGFloat = 40

    /// 头像圆角
    static let avatarCornerRadius: CGFloat = 5

    /// 头像到气泡间距
    static let avatarToBubbleGap: CGFloat = 10

    /// 行纵向间距
    static let rowVerticalSpacing: CGFloat = 10

    /// 气泡最大宽度比例
    static let bubbleMaxWidthRatio: CGFloat = 0.66

    /// 气泡水平内边距
    static let bubbleHorizontalPadding: CGFloat = 15

    /// 气泡纵向内边距
    static let bubbleVerticalPadding: CGFloat = 10

    /// 气泡圆角
    static let bubbleCornerRadius: CGFloat = 5

    /// 气泡文本字号
    static let bubbleFontSize: CGFloat = 17

    /// 气泡 tail 宽
    static let bubbleTailWidth: CGFloat = 6

    /// 气泡 tail 高
    static let bubbleTailHeight: CGFloat = 8

    /// 气泡 tail 距顶部偏移
    static let bubbleTailTopOffset: CGFloat = 12

    // MARK: - TopBar

    /// 顶部栏高度
    static let topBarHeight: CGFloat = 56

    /// 顶部栏标题字号
    static let topBarTitleSize: CGFloat = 17

    // MARK: - InputBar

    /// 输入栏总高
    static let inputBarHeight: CGFloat = 64

    /// 输入框高度
    static let inputFieldHeight: CGFloat = 40

    /// 输入框圆角
    static let inputFieldCornerRadius: CGFloat = 5

    /// 图标 touch area
    static let iconTouchArea: CGFloat = 44
}
