import SwiftUI
import MapKit
import CoreLocation

struct EditLocationView: View {
    @Environment(\.dismiss) private var dismiss
    let location: Location
    let projectStore: ProjectStore
    let project: Project
    
    @State private var editedLocation: Location
    @State private var showMapPicker = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMapItem: MKMapItem?
    @State private var isSearching = false
    @State private var region: MKCoordinateRegion
    @State private var mapPosition: MapCameraPosition
    @State private var addressFromCoordinate = ""
    @StateObject private var locationManager = LocationManager()
    
    init(location: Location, projectStore: ProjectStore, project: Project) {
        self.location = location
        self.projectStore = projectStore
        self.project = project
        self._editedLocation = State(initialValue: location)
        
        // 初始化地图位置
        let coordinate = location.coordinate ?? CLLocationCoordinate2D(latitude: 39.9087, longitude: 116.3975) // 默认北京坐标
        self._region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        self._mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("场地名称", text: Binding(
                        get: { editedLocation.name },
                        set: { editedLocation.name = $0 }
                    ))
                    
                    // 场地类型选择器
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("场地类型")
                            Spacer()
                            NavigationLink(destination: LocationTypeManagementView()) {
                                Text("管理类型")
                                    .font(.caption)
                                    .foregroundColor(project.color)
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LocationType.allCases, id: \.self) { locationType in
                                    Button(action: {
                                        editedLocation.type = locationType
                                    }) {
                                        Text(locationType.rawValue)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(editedLocation.type == locationType ? project.color : Color(.systemGray5))
                                            .foregroundColor(editedLocation.type == locationType ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    TextField("详细地址", text: Binding(
                        get: { editedLocation.address },
                        set: { editedLocation.address = $0 }
                    ))
                }
                
                // 位置信息部分
                Section("位置定位") {
                    // 显示当前坐标状态
                    HStack {
                        Text("定位状态")
                        Spacer()
                        Text(editedLocation.hasCoordinates ? "已设置" : "未设置")
                            .foregroundStyle(editedLocation.hasCoordinates ? .green : .secondary)
                    }
                    
                    // 地图设置按钮
                    Button {
                        searchText = editedLocation.address
                        showMapPicker = true
                    } label: {
                        Label("设置地图位置", systemImage: "map")
                    }
                    
                    // 如果已设置位置，添加清除选项
                    if editedLocation.hasCoordinates {
                        Button(role: .destructive) {
                            editedLocation.latitude = nil
                            editedLocation.longitude = nil
                        } label: {
                            Label("清除位置信息", systemImage: "xmark.circle")
                        }
                    }
                }
                
                Section("状态") {
                    Picker("场地状态", selection: $editedLocation.status) {
                        ForEach(LocationStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
                
                Section("联系方式") {
                    TextField("联系人", text: Binding(
                        get: { editedLocation.contactName ?? "" },
                        set: { editedLocation.contactName = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("联系电话", text: Binding(
                        get: { editedLocation.contactPhone ?? "" },
                        set: { editedLocation.contactPhone = $0.isEmpty ? nil : $0 }
                    ))
                        .keyboardType(.phonePad)
                }
                
                Section("备注") {
                    TextEditor(text: Binding(
                        get: { editedLocation.notes ?? "" },
                        set: { editedLocation.notes = $0.isEmpty ? nil : $0 }
                    ))
                        .frame(height: 100)
                }
            }
            .navigationTitle("编辑场地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            // 保存前打印调试信息
                            print("保存前的位置信息:")
                            print("- 名称: \(editedLocation.name)")
                            print("- 地址: \(editedLocation.address)")
                            print("- 坐标: \(editedLocation.hasCoordinates ? "有坐标" : "无坐标")")
                            if editedLocation.hasCoordinates {
                                print("- 纬度: \(editedLocation.latitude!), 经度: \(editedLocation.longitude!)")
                            }
                            
                            // 确保 hasCoordinates 属性与实际值一致
                            let hasCoordinates = editedLocation.latitude != nil && editedLocation.longitude != nil
                            if hasCoordinates != editedLocation.hasCoordinates {
                                print("警告：hasCoordinates 不一致，修正中...")
                                // 如果不一致，我们创建一个新的 Location 对象保持一致性
                                var updatedLocation = editedLocation
                                // 如果应该有坐标但 hasCoordinates 是 false，则不需要修复
                                // 如果不应该有坐标但 hasCoordinates 是 true，则清理坐标
                                if !hasCoordinates && editedLocation.hasCoordinates {
                                    print("- 清除坐标信息")
                                    updatedLocation.latitude = nil
                                    updatedLocation.longitude = nil
                                }
                                editedLocation = updatedLocation
                            }
                            
                            // 进行保存操作
                            await projectStore.updateLocation(editedLocation, in: project)
                            
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    }
                    .disabled(editedLocation.name.isEmpty || editedLocation.address.isEmpty)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                NavigationStack {
                    VStack {
                        // 搜索区域
                        VStack {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                
                                TextField("搜索地址", text: $searchText)
                                    .autocorrectionDisabled()
                                    .submitLabel(.search)
                                    .onSubmit {
                                        searchLocations()
                                    }
                                
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        searchResults = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            
                            if isSearching {
                                ProgressView()
                                    .padding(.top, 20)
                            }
                        }
                        .padding([.horizontal, .top])
                        .onAppear {
                            // 打开地图时，如果已经有坐标，更新地图位置
                            if let coordinate = editedLocation.coordinate {
                                let newRegion = MKCoordinateRegion(
                                    center: coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                                region = newRegion
                                mapPosition = .region(newRegion)
                            }
                        }
                        
                        // 搜索结果列表
                        if !searchResults.isEmpty {
                            List {
                                Section("搜索结果") {
                                    ForEach(searchResults, id: \.self.hashValue) { item in
                                        Button {
                                            selectLocation(item: item)
                                        } label: {
                                            VStack(alignment: .leading) {
                                                Text(item.name ?? "未知地点")
                                                    .font(.headline)
                                                Text(formatAddress(for: item))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // 地图视图
                            Map(position: $mapPosition, interactionModes: .all) {
                                if let coordinate = editedLocation.coordinate {
                                    Marker("所选位置", coordinate: coordinate)
                                        .tint(.red)
                                }
                            }
                            .overlay(alignment: .center) {
                                // 长按时的视觉指示
                                if editedLocation.hasCoordinates {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.green)
                                        .padding(8)
                                        .background(Color.white.opacity(0.7))
                                        .clipShape(Circle())
                                        .opacity(0.8)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                VStack(spacing: 10) {
                                    // 使用当前位置按钮
                                    HStack {
                                        Button {
                                            useCurrentLocation()
                                        } label: {
                                            Label("定位当前位置", systemImage: "location.fill")
                                                .padding(10)
                                                .frame(maxWidth: .infinity)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(10)
                                        }
                                        
                                        if editedLocation.hasCoordinates {
                                            Button {
                                                showMapPicker = false
                                            } label: {
                                                Label("确认使用", systemImage: "checkmark")
                                                    .padding(10)
                                                    .frame(maxWidth: .infinity)
                                                    .background(Color.green.opacity(0.2))
                                                    .foregroundColor(.green)
                                                    .cornerRadius(10)
                                            }
                                        }
                                    }
                                    
                                    Text("提示：点击地图任意位置可直接选取坐标")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(10)
                                .padding()
                            }
                            .overlay(alignment: .top) {
                                if editedLocation.hasCoordinates {
                                    Text("已选择位置：\(editedLocation.address)")
                                        .font(.caption)
                                        .padding(8)
                                        .background(Color(.systemBackground).opacity(0.8))
                                        .cornerRadius(8)
                                        .padding(.top, 10)
                                }
                            }
                            .mapControls {
                                MapCompass()
                                MapScaleView()
                            }
                            
                            // 长按选择位置
                            .onTapGesture { location in
                                getCoordinateFromTapLocation(location)
                            }
                        }
                        
                        Spacer()
                    }
                    .navigationTitle("选择位置")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showMapPicker = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func searchLocations() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            guard let response = response, error == nil else {
                searchResults = []
                return
            }
            
            searchResults = response.mapItems
        }
    }
    
    private func selectLocation(item: MKMapItem) {
        selectedMapItem = item
        let coordinate = item.placemark.coordinate
        
        editedLocation.latitude = coordinate.latitude
        editedLocation.longitude = coordinate.longitude
        
        // 打印调试信息
        print("设置位置坐标: 纬度 \(coordinate.latitude), 经度 \(coordinate.longitude)")
        print("editedLocation.hasCoordinates = \(editedLocation.hasCoordinates)")
        
        // 更新地址
        if let name = item.name, !name.isEmpty,
           let address = formatDetailedAddress(for: item) {
            editedLocation.address = "\(name), \(address)"
        } else if let address = formatDetailedAddress(for: item) {
            editedLocation.address = address
        }
        
        // 更新地图位置
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        region = newRegion
        mapPosition = .region(newRegion)
        
        // 清除搜索状态
        searchResults = []
        searchText = ""
        
        // 在搜索结果选择后显示成功反馈并自动确认
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showMapPicker = false
        }
    }
    
    private func getCoordinateFromTapLocation(_ tapLocation: CGPoint) {
        // 由于SwiftUI的Map组件限制，我们需要使用一个近似的方法
        // 在实际应用中，可以考虑使用MapKit的MKMapView来获得更精确的坐标转换
        
        // 获取当前地图的可见区域
        let mapCenter = region.center
        let mapSpan = region.span
        
        // 假设地图视图的大小（这里需要根据实际情况调整）
        let mapViewSize = CGSize(width: UIScreen.main.bounds.width - 40, height: 400) // 减去padding
        
        // 计算点击位置相对于地图中心的偏移
        let centerX = mapViewSize.width / 2
        let centerY = mapViewSize.height / 2
        
        let offsetX = tapLocation.x - centerX
        let offsetY = tapLocation.y - centerY
        
        // 将像素偏移转换为经纬度偏移
        let latitudeOffset = -(offsetY / mapViewSize.height) * mapSpan.latitudeDelta
        let longitudeOffset = (offsetX / mapViewSize.width) * mapSpan.longitudeDelta
        
        // 计算实际坐标
        let actualLatitude = mapCenter.latitude + latitudeOffset
        let actualLongitude = mapCenter.longitude + longitudeOffset
        
        // 更新场地信息
        editedLocation.latitude = actualLatitude
        editedLocation.longitude = actualLongitude
        
        print("用户点击位置: 屏幕坐标(\(tapLocation.x), \(tapLocation.y))")
        print("转换后的地图坐标: 纬度 \(actualLatitude), 经度 \(actualLongitude)")
        print("editedLocation.hasCoordinates = \(editedLocation.hasCoordinates)")
        
        // 反向地理编码获取地址
        let location = CLLocation(latitude: actualLatitude, longitude: actualLongitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                print("反向地理编码失败: \(error?.localizedDescription ?? "未知错误")")
                return
            }
            
            // 格式化地址
            var addressComponents: [String] = []
            
            if let name = placemark.name { addressComponents.append(name) }
            if let street = placemark.thoroughfare { addressComponents.append(street) }
            if let subArea = placemark.subLocality { addressComponents.append(subArea) }
            if let area = placemark.locality { addressComponents.append(area) }
            if let city = placemark.administrativeArea { addressComponents.append(city) }
            if let country = placemark.country { addressComponents.append(country) }
            
            let formattedAddress = addressComponents.joined(separator: ", ")
            
            DispatchQueue.main.async {
                if !formattedAddress.isEmpty {
                    self.editedLocation.address = formattedAddress
                    print("获取到地址: \(formattedAddress)")
                }
            }
        }
    }
    
    private func useCurrentLocation() {
        locationManager.requestLocation()
        
        // 使用 locationManager 的位置
        if let coordinate = locationManager.location?.coordinate {
            editedLocation.latitude = coordinate.latitude
            editedLocation.longitude = coordinate.longitude
            
            // 打印调试信息
            print("设置当前位置: 纬度 \(coordinate.latitude), 经度 \(coordinate.longitude)")
            print("editedLocation.hasCoordinates = \(editedLocation.hasCoordinates)")
            
            // 更新地图位置
            let newRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            region = newRegion
            mapPosition = .region(newRegion)
            
            // 反向地理编码获取地址
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let geocoder = CLGeocoder()
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                guard let placemark = placemarks?.first, error == nil else {
                    return
                }
                
                // 格式化地址
                var addressComponents: [String] = []
                
                if let name = placemark.name { addressComponents.append(name) }
                if let street = placemark.thoroughfare { addressComponents.append(street) }
                if let subArea = placemark.subLocality { addressComponents.append(subArea) }
                if let area = placemark.locality { addressComponents.append(area) }
                if let city = placemark.administrativeArea { addressComponents.append(city) }
                if let country = placemark.country { addressComponents.append(country) }
                
                let address = addressComponents.joined(separator: ", ")
                
                if !address.isEmpty {
                    editedLocation.address = address
                    print("更新地址: \(address)")
                    
                    // 自动关闭地图选择器，简化用户操作
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showMapPicker = false
                    }
                }
            }
        }
    }
    
    private func formatAddress(for mapItem: MKMapItem) -> String {
        let placemark = mapItem.placemark
        var address = ""
        
        if let street = placemark.thoroughfare {
            address += street
        }
        
        if let subArea = placemark.subLocality {
            if !address.isEmpty { address += ", " }
            address += subArea
        }
        
        if let area = placemark.locality {
            if !address.isEmpty { address += ", " }
            address += area
        }
        
        if let city = placemark.administrativeArea {
            if !address.isEmpty { address += ", " }
            address += city
        }
        
        return address
    }
    
    private func formatDetailedAddress(for mapItem: MKMapItem) -> String? {
        let placemark = mapItem.placemark
        var components: [String] = []
        
        if let street = placemark.thoroughfare { components.append(street) }
        if let subArea = placemark.subLocality { components.append(subArea) }
        if let area = placemark.locality { components.append(area) }
        if let city = placemark.administrativeArea { components.append(city) }
        if let country = placemark.country { components.append(country) }
        
        if components.isEmpty { return nil }
        return components.joined(separator: ", ")
    }
} 