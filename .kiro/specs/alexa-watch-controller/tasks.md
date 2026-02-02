# Implementation Plan: Alexa Watch Controller

## Overview

本实现计划将 Alexa Watch Controller 的设计分解为可执行的编码任务。项目包含两个应用：watchOS 主应用和 iOS 配套应用，使用 SwiftUI 和 MVVM 架构。

## Tasks

- [x] 1. 项目初始化和基础结构
  - [x] 1.1 创建 Xcode 项目，包含 watchOS App 和 iOS Companion App targets
    - 配置 Bundle ID 和 App Groups
    - 设置 WatchConnectivity capability
    - _Requirements: 1.1, 1.4_
  
  - [x] 1.2 创建核心数据模型
    - 实现 SmartPlug, DeviceState, AuthToken, AppError, CachedDeviceList 结构体
    - 添加 Codable 和 Equatable 协议实现
    - _Requirements: 2.2, 3.1_
  
  - [x] 1.3 编写数据模型属性测试
    - **Property 10: Cache Round-Trip**
    - 测试 SmartPlug 和 AuthToken 的编解码往返
    - **Validates: Requirements 5.1, 5.2**

- [x] 2. 服务层实现
  - [x] 2.1 实现 AuthService
    - 创建 AuthServiceProtocol 接口
    - 实现 OAuth 流程发起、回调处理、Token 刷新
    - 使用 Keychain 安全存储 Token
    - _Requirements: 1.2, 1.3, 1.5_
  
  - [x] 2.2 编写 AuthService 属性测试
    - **Property 1: Token Storage Persistence**
    - **Property 3: Expired Token Detection**
    - **Validates: Requirements 1.3, 1.5, 7.2**
  
  - [x] 2.3 实现 AlexaService
    - 创建 AlexaServiceProtocol 接口
    - 实现设备列表获取 (fetchDevices)
    - 实现设备状态切换 (toggleDevice)
    - 处理 API 错误和网络错误
    - _Requirements: 2.1, 3.1, 7.1_
  
  - [x] 2.4 实现 CacheService
    - 创建 CacheServiceProtocol 接口
    - 使用 UserDefaults 或文件系统存储缓存
    - 实现缓存过期检测 (24小时)
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  
  - [x] 2.5 编写 CacheService 属性测试
    - **Property 10: Cache Round-Trip**
    - **Property 11: Cache Staleness Detection**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
  
  - [x] 2.6 实现 ConnectivityService
    - 创建 ConnectivityServiceProtocol 接口
    - 实现 WatchConnectivity 消息发送和接收
    - 处理 Token 同步
    - _Requirements: 1.4_
  
  - [x] 2.7 编写 ConnectivityService 属性测试
    - **Property 2: Token Sync Round-Trip**
    - **Validates: Requirements 1.4**

- [x] 3. Checkpoint - 服务层测试通过
  - 确保所有服务层测试通过，如有问题请询问用户

- [x] 4. ViewModel 层实现
  - [x] 4.1 实现 AuthViewModel
    - 管理认证状态 (isAuthenticated, isLoading, error)
    - 实现 login(), logout(), checkAuthStatus() 方法
    - 处理 Token 过期和刷新逻辑
    - _Requirements: 1.1, 1.5, 1.6, 7.2_
  
  - [x] 4.2 实现 DeviceViewModel
    - 管理设备列表状态 (devices, isLoading, error, isUsingCache)
    - 实现 loadDevices(), toggleDevice(), refresh() 方法
    - 处理缓存逻辑和错误恢复
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4_
  
  - [x] 4.3 编写 DeviceViewModel 属性测试
    - **Property 4: Device Fetch on Valid Auth**
    - **Property 7: Toggle State Inversion**
    - **Property 8: Toggle Failure Rollback**
    - **Property 9: Loading State Consistency**
    - **Validates: Requirements 2.1, 3.1, 3.3, 3.4, 3.2, 4.5**

- [x] 5. Watch App UI 实现
  - [x] 5.1 实现 DeviceListView
    - 使用 SwiftUI List 显示设备列表
    - 支持下拉刷新 (.refreshable)
    - 显示加载状态和错误状态
    - 显示缓存数据提示
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 4.1, 4.5, 5.3_
  
  - [x] 5.2 实现 DeviceRowView
    - 显示设备名称和状态图标 (SF Symbols)
    - 点击触发切换操作
    - 显示操作中的加载指示器
    - _Requirements: 3.1, 3.2, 4.2_
  
  - [x] 5.3 实现 AuthPromptView
    - 显示未认证提示
    - 引导用户在 iPhone 上完成登录
    - _Requirements: 1.1, 7.2_
  
  - [x] 5.4 实现 ErrorView
    - 显示错误消息和操作指导
    - 提供重试按钮
    - _Requirements: 7.1, 7.4_
  
  - [x] 5.5 添加触觉反馈
    - 在状态切换成功时触发 WKInterfaceDevice haptic
    - _Requirements: 3.5_
  
  - [x] 5.6 编写 UI 单元测试
    - 测试空设备列表显示
    - 测试错误状态显示
    - 测试加载状态显示
    - _Requirements: 2.3, 2.4, 4.5_

- [x] 6. Checkpoint - Watch App 基础功能测试
  - 确保 Watch App 基础功能测试通过，如有问题请询问用户

- [x] 7. Companion App UI 实现
  - [x] 7.1 实现 AuthenticationView
    - 显示 Amazon 登录按钮
    - 处理 OAuth 回调 URL
    - 显示认证状态和错误
    - _Requirements: 1.2, 1.6_
  
  - [x] 7.2 实现 StatusView
    - 显示当前认证状态
    - 提供登出功能
    - 显示与 Watch 的连接状态
    - _Requirements: 1.3, 1.4_
  
  - [x] 7.3 编写 Companion App 单元测试
    - 测试 OAuth 回调处理
    - 测试认证失败显示
    - _Requirements: 1.2, 1.6_

- [x] 8. Complications 实现
  - [x] 8.1 实现 ComplicationController
    - 支持 circular, rectangular, corner 表盘样式
    - 显示设备状态图标
    - 处理点击事件触发切换
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  
  - [x] 8.2 实现 ComplicationConfigurationView
    - 允许用户选择关联的智能插座
    - 保存 Complication 配置
    - _Requirements: 6.5, 6.6_
  
  - [x] 8.3 实现 Complication 状态更新
    - 在设备状态变化时更新 Complication
    - 使用 CLKComplicationServer.sharedInstance().reloadTimeline
    - _Requirements: 6.4_
  
  - [x] 8.4 编写 Complication 属性测试
    - **Property 12: Complication State Consistency**
    - **Validates: Requirements 6.2, 6.3, 6.4**

- [x] 9. 错误处理和日志
  - [x] 9.1 实现统一错误处理
    - 创建 ErrorHandler 类
    - 实现错误日志记录
    - 确保所有错误消息包含操作指导
    - _Requirements: 7.3, 7.4_
  
  - [x] 9.2 编写错误处理属性测试
    - **Property 14: Error Logging**
    - **Property 15: Error Message Guidance**
    - **Validates: Requirements 7.3, 7.4**

- [x] 10. 集成和最终测试
  - [x] 10.1 集成所有组件
    - 连接 ViewModel 和 Service 层
    - 配置依赖注入
    - 设置 App 入口点
    - _Requirements: All_
  
  - [x] 10.2 编写集成测试
    - 测试完整的认证流程
    - 测试设备列表加载和切换
    - 测试 Complication 交互
    - _Requirements: 1.1-1.6, 2.1-2.5, 3.1-3.5_

- [x] 11. Final Checkpoint - 所有测试通过
  - 确保所有测试通过，如有问题请询问用户

## Notes

- 所有任务都是必需的，包括测试任务
- 每个任务都引用了具体的需求编号以便追溯
- 属性测试使用 SwiftCheck 框架，每个测试至少运行 100 次迭代
- Checkpoint 任务用于阶段性验证，确保增量开发的稳定性
