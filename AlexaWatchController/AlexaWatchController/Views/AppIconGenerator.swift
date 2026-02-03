//
//  AppIconGenerator.swift
//  AlexaWatchController
//
//  用于生成 App 图标的视图
//  在模拟器中运行后截图保存为 1024x1024 PNG
//

import SwiftUI

#if DEBUG

/// App 图标生成器视图
/// 运行后截图保存为 app-icon.png
struct AppIconGenerator: View {
    var body: some View {
        ZStack {
            // 渐变背景 - Alexa 蓝色调
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.6, blue: 0.9),  // 浅蓝
                    Color(red: 0.0, green: 0.4, blue: 0.8)   // 深蓝
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 插座图标
            VStack(spacing: 20) {
                // 电源插头图标
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 400, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

/// 小尺寸图标预览
struct AppIconSmall: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.6, blue: 0.9),
                    Color(red: 0.0, green: 0.4, blue: 0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "powerplug.fill")
                .font(.system(size: 60, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 27))
    }
}

struct AppIconGenerator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            AppIconSmall()
            
            Text("在 Canvas 中右键点击大图标")
            Text("选择 'Export...' 保存为 PNG")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        
        AppIconGenerator()
            .previewDisplayName("1024x1024 Icon")
    }
}

#endif
