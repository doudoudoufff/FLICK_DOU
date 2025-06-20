import SwiftUI
import MultipeerConnectivity

struct VenueReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    
    let sharePackage: VenueSharePackage
    let sender: MCPeerID
    let onResponse: (Bool) -> Void
    
    @State private var isAccepting = false
    @State private var conflictVenue: VenueEntity?
    @State private var showingConflictAlert = false
    
    private let venueManager = VenueManager(context: PersistenceController.shared.container.viewContext)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 发送者信息卡片
                    SenderInfoCard(sender: sender, sharePackage: sharePackage)
                        .padding(.horizontal)
                    
                    // 场地信息预览
                    VenueInfoPreview(venueData: sharePackage.venue)
                        .padding(.horizontal)
                    
                    // 附件预览
                    if !sharePackage.attachments.isEmpty {
                        AttachmentsPreview(attachments: sharePackage.attachments)
                            .padding(.horizontal)
                    }
                    
                    // 冲突警告（如果存在）
                    if let conflict = conflictVenue {
                        ConflictWarning(existingVenue: conflict, newVenue: sharePackage.venue)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("场地分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("拒绝") {
                        onResponse(false)
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("接收") {
                        acceptShare()
                    }
                    .disabled(isAccepting)
                }
            }
            .onAppear {
                checkForConflicts()
            }
            .overlay(
                // 接收进度遮罩
                Group {
                    if isAccepting {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("正在接收场地...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
                }
            )
            .alert("场地冲突", isPresented: $showingConflictAlert) {
                Button("覆盖现有场地") {
                    confirmAcceptShare(overwrite: true)
                }
                .foregroundColor(.red)
                
                Button("保留两个场地") {
                    confirmAcceptShare(overwrite: false)
                }
                
                Button("取消", role: .cancel) {
                    isAccepting = false
                }
            } message: {
                Text("发现相似的场地「\(conflictVenue?.wrappedName ?? "")」，请选择处理方式。")
            }
        }
    }
    
    private func checkForConflicts() {
        // 检查是否存在同名或同地址的场地
        let venues = venueManager.venues
        
        for venue in venues {
            let nameMatch = venue.wrappedName.lowercased() == sharePackage.venue.name.lowercased()
            let addressMatch = venue.wrappedAddress.lowercased().contains(sharePackage.venue.address.lowercased()) ||
                              sharePackage.venue.address.lowercased().contains(venue.wrappedAddress.lowercased())
            
            if nameMatch || addressMatch {
                conflictVenue = venue
                break
            }
        }
    }
    
    private func acceptShare() {
        if conflictVenue != nil {
            showingConflictAlert = true
        } else {
            confirmAcceptShare(overwrite: false)
        }
    }
    
    private func confirmAcceptShare(overwrite: Bool) {
        isAccepting = true
        
        // 实际导入场地数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 导入场地到数据库
            let importedVenue = self.venueManager.importSharedVenue(self.sharePackage, overwriteExisting: overwrite)
            
            if importedVenue != nil {
                print("VenueReceiveView: 成功导入场地 \(self.sharePackage.venue.name)")
                
                // 通知发送方已接受
                self.onResponse(true)
                
                // 显示成功UI
                self.isAccepting = false
                self.dismiss()
            } else {
                print("VenueReceiveView: 导入场地失败")
                
                // 通知发送方已拒绝
                self.onResponse(false)
                
                // 显示失败UI
                self.isAccepting = false
                self.dismiss()
            }
        }
    }
}

// MARK: - 子视图组件

struct SenderInfoCard: View {
    let sender: MCPeerID
    let sharePackage: VenueSharePackage
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("来自")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(sender.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("分享时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(sharePackage.timestamp, format: .dateTime.hour().minute())
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            
            Divider()
            
            HStack {
                Label("设备信息", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("FLICK \(sharePackage.sender.appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct VenueInfoPreview: View {
    let venueData: VenueShareData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("场地信息")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                VenueShareInfoRow(icon: "building.2.fill", label: "场地名称", value: venueData.name)
                VenueShareInfoRow(icon: "tag.fill", label: "场地类型", value: venueData.type)
                VenueShareInfoRow(icon: "mappin.and.ellipse", label: "地址", value: venueData.address)
                VenueShareInfoRow(icon: "person.fill", label: "联系人", value: venueData.contactName)
                VenueShareInfoRow(icon: "phone.fill", label: "电话", value: venueData.contactPhone)
                
                if !venueData.notes.isEmpty {
                    VenueShareInfoRow(icon: "note.text", label: "备注", value: venueData.notes)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct VenueShareInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct AttachmentsPreview: View {
    let attachments: [AttachmentShareData]
    
    var imageAttachments: [AttachmentShareData] {
        attachments.filter { $0.fileType == "image" }
    }
    
    var pdfAttachments: [AttachmentShareData] {
        attachments.filter { $0.fileType == "pdf" }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("附件预览")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 图片预览
            if !imageAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("图片 (\(imageAttachments.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(imageAttachments.prefix(4), id: \.id) { attachment in
                            if let image = UIImage(data: attachment.data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        if imageAttachments.count > 4 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 80)
                                
                                Text("+\(imageAttachments.count - 4)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // PDF预览
            if !pdfAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PDF文档 (\(pdfAttachments.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(pdfAttachments, id: \.id) { attachment in
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachment.fileName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.data.count), countStyle: .file))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct ConflictWarning: View {
    let existingVenue: VenueEntity
    let newVenue: VenueShareData
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("发现相似场地")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("您已经有一个相似的场地：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("现有：\(existingVenue.wrappedName)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text(existingVenue.wrappedAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("新场地：\(newVenue.name)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text(newVenue.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Text("接收时将询问您如何处理冲突")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    let samplePackage = VenueSharePackage(
        venue: VenueShareData(
            name: "示例摄影棚",
            address: "北京市朝阳区示例地址123号",
            contactName: "张先生",
            contactPhone: "13800138000",
            type: "摄影棚",
            notes: "这是一个测试场地的备注信息",
            dateAdded: Date()
        ),
        attachments: [],
        sender: SenderInfo()
    )
    
    let sampleSender = MCPeerID(displayName: "李制片的iPhone")
    
    return VenueReceiveView(
        sharePackage: samplePackage,
        sender: sampleSender,
        onResponse: { _ in }
    )
} 