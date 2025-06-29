# 路书功能开发文档

## 功能概述

路书功能是FLICK应用的一个全新独立功能模块，主要用于帮助剧组成员在陌生拍摄场地进行导航。

### 使用场景
- 当剧组成员首次到达陌生拍摄场地时
- 需要为器材公司的器材车和其他剧组成员提供清晰的进场路线指引
- 制片需要提供图片指引，说明从大门或马路边如何进入场地

### 当前痛点
- 现有流程繁琐：需要拍照 → 编辑图片 → 在图片上绘制指引线路 → 拼接成长图片 → 发送给剧组成员
- 通常需要使用电脑完成编辑和拼接工作
- 过程耗时且不便捷

### 功能需求
1. **拍照功能**：沿着进场路线逐步拍摄照片
2. **照片编辑**：
   - 拍摄完一张照片后立即进入编辑模式
   - 在照片上绘制指引线路、箭头等标注
   - 可能需要标注人员、车辆应该如何行进
3. **照片组织**：按顺序组织多张已编辑的照片
4. **生成输出**：将所有照片自动拼接成一个长图片，形成完整的路书指引
5. **分享功能**：方便分享给剧组其他成员

### 用户流程
1. 用户打开路书功能
2. 拍摄第一张照片
3. 照片拍摄完成后自动进入编辑界面
4. 用户在照片上添加指引标记
5. 确认编辑后继续拍摄下一张照片
6. 重复步骤2-5直到完成所有照片拍摄和编辑
7. 生成最终路书长图
8. 分享给剧组成员

## 实现计划

### 文件结构
```
FLICK/Roadbook/
├── Models/
│   ├── Roadbook.swift                 # 路书模型
│   └── RoadbookPhoto.swift            # 路书照片模型
├── Views/
│   ├── RoadbookView.swift             # 主视图
│   ├── RoadbookCreationView.swift     # 创建流程视图
│   ├── RoadbookCameraView.swift       # 相机视图
│   ├── RoadbookDrawingView.swift      # 绘图编辑视图
│   ├── DrawingToolbar.swift           # 绘图工具栏
│   ├── RoadbookPreviewView.swift      # 预览视图
│   └── RoadbookShareView.swift        # 分享视图
├── Managers/
│   ├── RoadbookManager.swift          # 路书数据管理
│   ├── DrawingManager.swift           # 绘图功能管理
│   └── ImageProcessor.swift           # 图片处理工具
└── Extensions/
    └── UIImage+Roadbook.swift         # UIImage扩展方法
```

### 开发阶段
1. **基础设置和模型定义** ✅
   - 创建文件结构 ✅
   - 定义数据模型 ✅
   - 更新CoreData模型 ✅
   - 创建CoreData实体类 ✅

2. **核心管理器实现** ✅
   - 路书管理器 (RoadbookManager) ✅
   - 绘图管理器 (DrawingManager) ✅
   - ~~图片处理工具~~ (部分功能已在管理器中实现)

3. **数据持久化完善** ✅
   - 实现CoreData CRUD操作 ✅
   - 实现模型与实体转换 ✅
   - 优化数据加载和保存性能 ✅
   - 添加CloudKit兼容性 ✅

4. **用户界面开发** ⏳
   - 实现主路书视图 ✅
   - 实现路书详情视图 ✅
   - 开发相机界面 ⏳
   - 创建绘图编辑界面 ⏳
   - 设计预览和分享界面 ⏳

5. **核心功能实现** ⏳
   - 相机拍摄功能 ⏳
   - 绘图引擎开发 ⏳
   - 图片处理和拼接 ✅
   - 数据持久化 ✅

6. **集成与优化** ⏳
   - 与现有应用集成 ✅
   - 性能优化 ⏳
   - 用户体验改进 ⏳

7. **测试与发布** ⏳
   - 功能测试 ⏳
   - 用户测试 ⏳
   - 发布准备 ⏳

## 进度跟踪

| 任务                     | 状态     | 完成日期   | 备注                 |
|--------------------------|----------|------------|----------------------|
| 创建项目文档             | 完成     | 2023-11-01 | 初始文档创建         |
| 创建目录结构             | 完成     | 2023-11-01 | 建立基本文件结构     |
| 设计数据模型             | 完成     | 2023-11-01 | 实现Roadbook和RoadbookPhoto模型 |
| 实现绘图元素模型         | 完成     | 2023-11-01 | 实现DrawingElement和相关类型 |
| 实现路书管理器           | 完成     | 2023-11-01 | 实现RoadbookManager类 |
| 实现绘图管理器           | 完成     | 2023-11-01 | 实现DrawingManager类 |
| 设计CoreData模型         | 完成     | 2023-11-01 | 添加路书相关实体到数据库模型 |
| 创建CoreData实体类       | 完成     | 2023-11-01 | 生成实体类和属性文件 |
| 完善CoreData CRUD操作    | 完成     | 2023-11-02 | 实现数据持久化和模型转换 |
| 添加CloudKit兼容性       | 完成     | 2023-11-03 | 修改CoreData模型以支持CloudKit同步 |
| 创建基础UI               | 部分完成 | 2023-11-02 | 实现了RoadbookView和RoadbookDetailView |
| 实现相机功能             | 未开始   |            |                      |
| 开发绘图功能             | 未开始   |            |                      |
| 实现图片拼接             | 完成     | 2023-11-01 | 基础算法已在RoadbookManager中实现 |
| 添加分享功能             | 部分完成 | 2023-11-02 | 基础分享框架已实现，但需要完善 |
| 与主应用集成             | 完成     | 2023-11-02 | 在FeatureView中添加了路书功能入口 |
| 测试与优化               | 未开始   |            |                      |

## 已完成工作回顾

### 1. 数据模型
- **Roadbook**: 实现了路书的基本模型，包含路书名称、创建日期、照片数组等属性，以及添加、移除、更新照片等方法
- **RoadbookPhoto**: 实现了路书照片模型，包含原始图片、编辑后图片、绘制数据等属性
- **DrawingElement**: 实现了绘制元素模型，支持线条、箭头、文本、矩形、椭圆等绘制类型

### 2. 管理器
- **RoadbookManager**: 实现了路书数据的CRUD操作，以及生成路书长图的功能
- **DrawingManager**: 实现了绘图功能，包括各种绘制工具、撤销、清除等操作，以及将绘制元素渲染到图片上的功能

### 3. CoreData模型
- **RoadbookEntity**: 路书实体，存储路书基本信息
  - 属性：id, name, creationDate, modificationDate, notes
  - 关系：photos (一对多), project (多对一)
- **RoadbookPhotoEntity**: 路书照片实体，存储照片数据和元信息
  - 属性：id, originalImageData, editedImageData, captureDate, note, orderIndex, latitude, longitude, thumbnailData
  - 关系：roadbook (多对一), drawingElements (一对多)
- **DrawingElementEntity**: 绘制元素实体，存储绘图数据
  - 属性：id, type, color, lineWidth, pointsData, text
  - 关系：roadbookPhoto (多对一)
- **ProjectEntity**: 更新了项目实体，添加了与路书的关系
  - 关系：roadbooks (一对多)

### 4. CoreData实体类
- **RoadbookEntity+CoreDataClass.swift**: 路书实体类定义
- **RoadbookEntity+CoreDataProperties.swift**: 路书实体属性定义，包括:
  - 基本属性：creationDate, id, modificationDate, name, notes
  - 关系：photos (NSSet), project
  - 生成的访问器方法，用于管理照片集合
- **RoadbookPhotoEntity+CoreDataClass.swift**: 路书照片实体类定义
- **RoadbookPhotoEntity+CoreDataProperties.swift**: 路书照片实体属性定义，包括:
  - 基本属性：captureDate, editedImageData, id, latitude, longitude, note, orderIndex, originalImageData, thumbnailData
  - 关系：drawingElements, roadbook
  - 生成的访问器方法，用于管理绘制元素集合
- **DrawingElementEntity+CoreDataClass.swift**: 绘制元素实体类定义
- **DrawingElementEntity+CoreDataProperties.swift**: 绘制元素实体属性定义，包括:
  - 基本属性：color, id, lineWidth, pointsData, text, type
  - 关系：roadbookPhoto

### 5. 数据持久化完善
- **CoreData CRUD操作**:
  - 实现了从CoreData加载路书数据的`fetchRoadbooksFromStorage`方法
  - 完善了保存路书到CoreData的`saveRoadbook`方法，支持新建和更新操作
  - 实现了删除路书的`deleteRoadbook`方法，确保同时清理内存和数据库
  - 优化了照片添加和更新操作，直接操作CoreData实体
  
- **模型与实体转换**:
  - 实现了`convertEntityToModel`方法，将CoreData实体转换为内存模型
  - 实现了`convertPhotoEntityToModel`方法，处理照片数据和元信息的转换
  - 实现了`convertDrawingElementEntityToModel`方法，处理绘制元素数据的转换
  - 实现了`createDrawingElementEntity`方法，将绘制元素模型转换为实体
  
- **性能优化**:
  - 使用后台线程加载数据，避免阻塞主线程
  - 实现了照片数据的异步处理
  - 优化了图片数据的存储和加载

### 6. CloudKit兼容性
- **CoreData模型优化**:
  - 将RoadbookEntity的photos关系从有序(ordered)改为无序，以兼容CloudKit
  - 将所有必需属性修改为可选或添加默认值，满足CloudKit要求
  - 为关键属性添加了默认值，确保数据一致性
  - 修复了CoreData与CloudKit集成的兼容性问题

### 7. 用户界面
- **RoadbookView**: 实现了路书列表主视图，包括:
  - 路书列表展示
  - 创建新路书功能
  - 删除路书功能
  - 空状态和加载状态处理
- **RoadbookDetailView**: 实现了路书详情视图，包括:
  - 路书信息展示
  - 照片网格展示
  - 添加照片功能入口
  - 生成长图功能
  - 分享功能

### 8. 应用集成
- 在FeatureView中添加了路书功能入口
- 确保了与应用整体风格一致
- 添加了适当的图标和描述

## 下一步工作

1. **完善相机功能**
   - 实现RoadbookCameraView相机视图
   - 添加照片拍摄和导入功能
   - 实现位置信息记录

2. **实现绘图编辑功能**
   - 开发RoadbookDrawingView绘图编辑视图
   - 实现DrawingToolbar绘图工具栏
   - 完善绘图交互体验

3. **增强图片处理功能**
   - 优化图片拼接算法
   - 添加图片裁剪和调整功能
   - 改进缩略图生成

4. **完善用户体验**
   - 添加操作引导
   - 优化交互流程
   - 增强视觉反馈

## 技术挑战与解决方案

### 1. 绘图功能实现
- **挑战**：在iOS上实现流畅的绘图体验
- **解决方案**：已实现DrawingManager，使用Core Graphics框架处理绘图操作，支持多种绘制工具和编辑功能

### 2. 图片处理性能
- **挑战**：处理和拼接大量高分辨率图片可能导致性能问题
- **解决方案**：
  - 已在RoadbookPhoto中实现图片压缩
  - 在RoadbookManager中实现了异步图片处理
  - 后续需要进一步优化大图片处理性能

### 3. 数据持久化
- **挑战**：存储包含大量图片数据的路书项目
- **解决方案**：
  - 已设计CoreData模型，将路书元数据存储在数据库中
  - 已创建CoreData实体类，为数据持久化做好准备
  - 已实现完整的CRUD操作和模型转换功能
  - 添加缩略图支持，优化列表加载性能
  - 使用JSON序列化存储复杂的绘制元素点数据

### 4. CloudKit集成
- **挑战**：确保CoreData模型与CloudKit兼容
- **解决方案**：
  - 修改了有序关系为无序关系
  - 将必需属性改为可选或添加默认值
  - 优化了数据模型结构以支持云同步
  - 确保了数据一致性和完整性

### 5. 用户体验
- **挑战**：确保整个流程简单直观
- **解决方案**：
  - 设计直观的用户界面
  - 实现自动化流程，减少用户操作步骤
  - 提供实时预览和编辑功能 

### 6. 数据一致性
- **挑战**：确保内存模型和持久化数据的一致性
- **解决方案**：
  - 实现了完善的模型与实体转换机制
  - 在关键操作后同步更新内存模型和持久化数据
  - 使用事务确保数据操作的原子性 