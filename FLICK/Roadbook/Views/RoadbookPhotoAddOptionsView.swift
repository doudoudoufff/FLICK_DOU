import SwiftUI

struct RoadbookPhotoAddOptionsView: View {
    @Binding var selectedImages: [UIImage]
    @Binding var showingAddPhoto: Bool
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Text("添加照片")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 20) {
                    // 拍照选项
                    Button(action: {
                        showingCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                            
                            Text("拍照")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    
                    // 相册选项
                    Button(action: {
                        showingPhotoLibrary = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.green)
                                .clipShape(Circle())
                            
                            Text("从相册选择")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("添加照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showingAddPhoto = false
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                RoadbookCameraView(capturedImage: $capturedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if let image = capturedImage {
                            // 处理拍摄的照片
                            selectedImages = [image]
                            showingAddPhoto = false
                        }
                    }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                RoadbookPhotoPickerView(selectedImages: $selectedImages, allowMultiple: true)
                    .onDisappear {
                        if !selectedImages.isEmpty {
                            showingAddPhoto = false
                        }
                    }
            }
        }
    }
} 