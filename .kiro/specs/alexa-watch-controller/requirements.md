# Requirements Document

## Introduction

本文档定义了 Apple Watch Alexa 智能插座控制器应用的需求。该应用允许用户通过 Apple Watch 查看和控制其 Alexa 账户下的智能插座设备，提供简洁直观的手表端操作体验。

## Glossary

- **Watch_App**: Apple Watch 上运行的 watchOS 应用程序
- **Companion_App**: 配套的 iPhone 应用，用于处理 OAuth 认证
- **Smart_Plug**: Alexa 兼容的智能插座设备
- **Alexa_API**: Amazon Alexa Smart Home API 服务
- **OAuth_Token**: 用于访问 Alexa API 的认证令牌
- **Device_List**: 用户账户下的智能插座设备列表
- **Device_State**: 智能插座的当前状态（开/关）

## Requirements

### Requirement 1: OAuth 认证

**User Story:** As a user, I want to authenticate with my Amazon account, so that I can access my Alexa smart home devices.

#### Acceptance Criteria

1. WHEN the user opens the Watch_App for the first time, THE Watch_App SHALL prompt the user to complete authentication via the Companion_App
2. WHEN the Companion_App initiates OAuth login, THE Companion_App SHALL redirect the user to Amazon's login page
3. WHEN the user successfully authenticates, THE Companion_App SHALL securely store the OAuth_Token
4. WHEN the OAuth_Token is stored, THE Companion_App SHALL sync the token to the Watch_App via WatchConnectivity
5. IF the OAuth_Token expires, THEN THE Watch_App SHALL notify the user to re-authenticate via the Companion_App
6. IF the OAuth authentication fails, THEN THE Companion_App SHALL display an error message and allow retry

### Requirement 2: 设备列表获取与显示

**User Story:** As a user, I want to see a list of my smart plugs on my Apple Watch, so that I can quickly identify which devices I can control.

#### Acceptance Criteria

1. WHEN the Watch_App launches with a valid OAuth_Token, THE Watch_App SHALL fetch the Device_List from the Alexa_API
2. WHEN the Device_List is retrieved, THE Watch_App SHALL display each Smart_Plug with its name and current Device_State
3. WHEN the Device_List is empty, THE Watch_App SHALL display a message indicating no smart plugs are found
4. IF the Alexa_API request fails, THEN THE Watch_App SHALL display an error message with a retry option
5. WHEN the user pulls down on the device list, THE Watch_App SHALL refresh the Device_List from the Alexa_API

### Requirement 3: 智能插座控制

**User Story:** As a user, I want to turn my smart plugs on or off from my Apple Watch, so that I can control my devices without using my phone.

#### Acceptance Criteria

1. WHEN the user taps on a Smart_Plug in the list, THE Watch_App SHALL toggle the Device_State of that plug
2. WHEN a toggle command is sent, THE Watch_App SHALL display a loading indicator until the operation completes
3. WHEN the toggle operation succeeds, THE Watch_App SHALL update the Device_State display to reflect the new state
4. IF the toggle operation fails, THEN THE Watch_App SHALL display an error message and revert the displayed state
5. WHEN the Device_State changes, THE Watch_App SHALL provide haptic feedback to confirm the action

### Requirement 4: 用户界面设计

**User Story:** As a user, I want a simple and intuitive interface on my Apple Watch, so that I can quickly control my devices with minimal interaction.

#### Acceptance Criteria

1. THE Watch_App SHALL display the device list using a scrollable List view optimized for small screens
2. THE Watch_App SHALL use clear on/off icons to indicate the current Device_State of each Smart_Plug
3. THE Watch_App SHALL support Digital Crown scrolling for navigating the Device_List
4. THE Watch_App SHALL use system colors and SF Symbols for consistent watchOS appearance
5. WHILE the Watch_App is loading data, THE Watch_App SHALL display a progress indicator

### Requirement 5: 数据同步与缓存

**User Story:** As a user, I want the app to remember my devices, so that I can see them quickly even when offline.

#### Acceptance Criteria

1. WHEN the Device_List is successfully fetched, THE Watch_App SHALL cache the list locally
2. WHEN the Watch_App launches without network connectivity, THE Watch_App SHALL display the cached Device_List
3. WHEN displaying cached data, THE Watch_App SHALL indicate that the data may be outdated
4. IF the cached data is older than 24 hours, THEN THE Watch_App SHALL prompt the user to refresh when connectivity is available

### Requirement 6: 表盘小组件（Complications）

**User Story:** As a user, I want to control my smart plugs directly from the watch face, so that I can toggle devices with a single tap without opening the app.

#### Acceptance Criteria

1. THE Watch_App SHALL provide Complications for multiple watch face families (circular, rectangular, corner)
2. WHEN a Complication is added to the watch face, THE Complication SHALL display the state of a user-selected Smart_Plug
3. WHEN the user taps on a Complication, THE Watch_App SHALL toggle the associated Smart_Plug's Device_State
4. WHEN the Device_State changes, THE Complication SHALL update to reflect the new state
5. THE Watch_App SHALL allow the user to configure which Smart_Plug is associated with each Complication
6. IF multiple smart plugs exist, THEN THE Watch_App SHALL provide a selection interface during Complication setup

### Requirement 7: 错误处理与恢复

**User Story:** As a user, I want clear feedback when something goes wrong, so that I can understand and resolve issues.

#### Acceptance Criteria

1. IF network connectivity is unavailable, THEN THE Watch_App SHALL display a connectivity error message
2. IF the OAuth_Token is invalid or missing, THEN THE Watch_App SHALL redirect the user to re-authenticate
3. WHEN an error occurs, THE Watch_App SHALL log the error details for debugging purposes
4. WHEN displaying an error, THE Watch_App SHALL provide actionable guidance to the user
5. IF a Complication action fails, THEN THE Watch_App SHALL display a brief notification on the watch face
