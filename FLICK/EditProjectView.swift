import SwiftUI
import PhotosUI

struct EditProjectView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @Binding var isPresented: Bool
    
    @State private var name: String
    @State private var director: String
    @State private var producer: String
    @State private var startDate: Date
    @State private var status: Project.Status
    @State private var selectedColor: Color
    @State private var logoData: Data?
    
    // 照片选择器状态
    @State private var selectedLogo: PhotosPickerItem?
    @State private var showingCropView = false
    @State private var selectedImage: UIImage?
    @State private var croppedImage: UIImage?
    
    init(project: Binding<Project>, isPresented: Binding<Bool>) {
        self._project = project
        self._isPresented = isPresented
        
        _name = State(initialValue: project.wrappedValue.name)
        _director = State(initialValue: project.wrappedValue.director)
        _producer = State(initialValue: project.wrappedValue.producer)
        _startDate = State(initialValue: project.wrappedValue.startDate)
        _status = State(initialValue: project.wrappedValue.status)
        _selectedColor = State(initialValue: project.wrappedValue.color)
        _logoData = State(initialValue: project.wrappedValue.logoData)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("项目名称", text: $name)
                    TextField("导演", text: $director)
                    TextField("制片", text: $producer)
                }
                
                Section(header: Text("项目状态")) {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    Picker("状态", selection: $status) {
                        ForEach(Project.Status.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
                
                Section(header: Text("项目颜色")) {
                    ColorPickerView(selectedColor: $selectedColor)
                }
                
                Section(header: Text("项目LOGO")) {
                    HStack {
                        if let logoData = logoData, let uiImage = UIImage(data: logoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .cornerRadius(8)
                        } else {
                            Text("未设置LOGO")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack {
                            PhotosPicker(selection: $selectedLogo, matching: .images) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title2)
                            }
                            .buttonStyle(.borderless)
                            
                            if logoData != nil {
                                Button(action: {
                                    logoData = nil
                                }) {
                                    Image(systemName: "trash")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Text("添加LOGO将在PDF报告中显示")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("编辑项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        print("[EditProjectView] 点击保存，当前project.color: \(selectedColor.toHex())，context: \(projectStore.context)")
                        project.name = name
                        project.director = director
                        project.producer = producer
                        project.startDate = startDate
                        project.status = status
                        project.color = selectedColor
                        project.logoData = logoData
                        
                        projectStore.updateProject(project)
                        
                        projectStore.objectWillChange.send()
                        
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onChange(of: selectedLogo) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        showingCropView = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCropView) {
                if let image = selectedImage {
                    ImageCropView(
                        image: image,
                        croppedImage: Binding(
                            get: { croppedImage },
                            set: { newImage in
                                croppedImage = newImage
                                if let compressedData = newImage?.jpegData(compressionQuality: 0.7) {
                                    logoData = compressedData
                                }
                            }
                        )
                    )
                }
            }
        }
    }
}

#Preview {
    EditProjectView(
        project: .constant(Project(
            name: "测试项目",
            director: "张导演",
            producer: "李制片"
        )),
        isPresented: .constant(true)
    )
} 