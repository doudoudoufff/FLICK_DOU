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
    
    // 新增状态
    @State private var isAutoLocating = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress: String?
    @State private var isGeocodingAddress = false
    
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
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    HStack {
                        Text("场地名称")
                        Text("*")
                            .foregroundColor(.red)
                            .font(.caption)
                        TextField("", text: $editedLocation.name)
                    }
                    
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
                    
                    TextField("详细地址", text: $editedLocation.address)
                }
                
                Section("位置定位") {
                    // 显示当前坐标状态
                    HStack {
                        Text("定位状态")
                        Spacer()
                        if isAutoLocating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("定位中...")
                                    .foregroundStyle(.blue)
                            }
                        } else {
                            Text(editedLocation.hasCoordinates ? "已设置" : "未设置")
                                .foregroundStyle(editedLocation.hasCoordinates ? .green : .secondary)
                        }
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
                
                Section(header: Text("联系方式")) {
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
                
                Section(header: Text("备注")) {
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
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await projectStore.updateLocation(editedLocation, in: project)
                            dismiss()
                        }
                    }
                    .disabled(editedLocation.name.isEmpty)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                NavigationStack {
                    VStack(spacing: 0) {
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
                        
                        // 搜索结果列表或地图视图
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
                            // 改进的地图视图
                            ZStack {
                                Map(position: $mapPosition, interactionModes: .all) {
                                    // 显示选中的位置
                                    if let coordinate = selectedCoordinate {
                                        Marker("选中位置", coordinate: coordinate)
                                            .tint(.red)
                                    }
                                    // 显示已保存的位置
                                    if let coordinate = editedLocation.coordinate, selectedCoordinate == nil {
                                        Marker("当前位置", coordinate: coordinate)
                                            .tint(.blue)
                                    }
                                }
                                .mapControls {
                                    MapCompass()
                                    MapScaleView()
                                    MapUserLocationButton()
                                }
                                .onMapCameraChange { context in
                                    region = context.region
                                }
                                .onTapGesture { screenPoint in
                                    handleMapTap(at: screenPoint)
                                }
                                
                                // 地图中心十字线指示器
                                if selectedCoordinate == nil && !editedLocation.hasCoordinates {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                        .background(
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 30, height: 30)
                                        )
                                        .shadow(radius: 2)
                                }
                                
                                // 底部操作面板
                                VStack {
                                    Spacer()
                                    
                                    VStack(spacing: 12) {
                                        // 位置信息显示
                                        if let coord = selectedCoordinate {
                                            Text("已选择位置")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            if isGeocodingAddress {
                                                HStack {
                                                    ProgressView()
                                                        .scaleEffect(0.7)
                                                    Text("获取地址中...")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            } else if let address = selectedAddress {
                                                Text(address)
                                                    .font(.caption2)
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                            } else {
                                                Text("纬度: \(coord.latitude, specifier: "%.6f")")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text("经度: \(coord.longitude, specifier: "%.6f")")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        } else if editedLocation.hasCoordinates {
                                            Text("当前已设置位置")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        } else {
                                            Text("点击地图选择位置或使用下方按钮")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        // 操作按钮
                                        HStack(spacing: 12) {
                                            // 使用当前位置按钮
                                            Button {
                                                useCurrentLocation()
                                            } label: {
                                                HStack {
                                                    if isAutoLocating {
                                                        ProgressView()
                                                            .scaleEffect(0.8)
                                                    } else {
                                                        Image(systemName: "location.fill")
                                                    }
                                                    Text("当前位置")
                                                }
                                                .font(.system(size: 14, weight: .medium))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(20)
                                            }
                                            .disabled(isAutoLocating)
                                            
                                            // 使用地图中心按钮
                                            if selectedCoordinate == nil && !editedLocation.hasCoordinates {
                                                Button {
                                                    useMapCenter()
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "scope")
                                                        Text("使用中心点")
                                                    }
                                                    .font(.system(size: 14, weight: .medium))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(Color.orange.opacity(0.1))
                                                    .foregroundColor(.orange)
                                                    .cornerRadius(20)
                                                }
                                            }
                                            
                                            // 确认按钮
                                            if selectedCoordinate != nil {
                                                Button {
                                                    confirmSelectedLocation()
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "checkmark")
                                                        Text("确认")
                                                    }
                                                    .font(.system(size: 14, weight: .medium))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(Color.green.opacity(0.1))
                                                    .foregroundColor(.green)
                                                    .cornerRadius(20)
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(.systemBackground))
                                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
                                    )
                                    .padding(.horizontal)
                                    .padding(.bottom)
                                }
                            }
                        }
                    }
                    .navigationTitle("选择位置")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                selectedCoordinate = nil
                                showMapPicker = false
                            }
                        }
                        
                        if editedLocation.hasCoordinates || selectedCoordinate != nil {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") {
                                    if selectedCoordinate != nil {
                                        confirmSelectedLocation()
                                    }
                                    showMapPicker = false
                                }
                            }
                        }
                    }
                    .onAppear {
                        setupMapOnAppear()
                    }
                }
            }
        }
    }
    
    // MARK: - 新的地图相关方法
    
    private func setupMapOnAppear() {
        // 如果已经有坐标，更新地图位置
        if let coordinate = editedLocation.coordinate {
            let newRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            region = newRegion
            mapPosition = .region(newRegion)
        } else {
            // 如果没有坐标，尝试自动定位
            autoLocateForMap()
        }
    }
    
    private func autoLocateForMap() {
        guard locationManager.hasLocationPermission else { return }
        
        if let coordinate = locationManager.currentCoordinate {
            let newRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            region = newRegion
            mapPosition = .region(newRegion)
        }
    }
    
    private func handleMapTap(at screenPoint: CGPoint) {
        // 使用地图中心作为选中点（更准确的方法）
        let centerCoordinate = region.center
        selectedCoordinate = centerCoordinate
        selectedAddress = nil
        
        // 获取地址信息
        isGeocodingAddress = true
        reverseGeocodeCoordinate(centerCoordinate) { addressString in
            self.selectedAddress = addressString ?? "无法获取地址信息"
            self.isGeocodingAddress = false
        }
    }
    
    private func useMapCenter() {
        selectedCoordinate = region.center
        selectedAddress = nil
        
        isGeocodingAddress = true
        reverseGeocodeCoordinate(region.center) { addressString in
            self.selectedAddress = addressString ?? "无法获取地址信息"
            self.isGeocodingAddress = false
        }
    }
    
    private func confirmSelectedLocation() {
        guard let coord = selectedCoordinate else { return }
        setLocationFromCoordinate(coord)
        selectedCoordinate = nil
        selectedAddress = nil
        isGeocodingAddress = false
        showMapPicker = false
    }
    
    private func setLocationFromCoordinate(_ coordinate: CLLocationCoordinate2D) {
        editedLocation.latitude = coordinate.latitude
        editedLocation.longitude = coordinate.longitude
        
        // 更新地图位置
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        region = newRegion
        mapPosition = .region(newRegion)
        
        // 获取地址信息
        reverseGeocodeCoordinate(coordinate) { addressString in
            if let addressString = addressString, !addressString.isEmpty {
                self.editedLocation.address = addressString
            }
        }
        
        print("设置位置: 纬度 \(coordinate.latitude), 经度 \(coordinate.longitude)")
        print("editedLocation.hasCoordinates = \(editedLocation.hasCoordinates)")
    }
    
    private func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                print("反向地理编码失败: \(error?.localizedDescription ?? "未知错误")")
                DispatchQueue.main.async {
                    completion(nil)
                }
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
                    print("获取到地址: \(formattedAddress)")
                    completion(formattedAddress)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - 原有方法的优化版本
    
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
        
        setLocationFromCoordinate(coordinate)
        
        // 更新地址
        if let name = item.name, !name.isEmpty,
           let address = formatDetailedAddress(for: item) {
            editedLocation.address = "\(name), \(address)"
        } else if let address = formatDetailedAddress(for: item) {
            editedLocation.address = address
        }
        
        // 清除搜索状态
        searchResults = []
        searchText = ""
        
        // 在搜索结果选择后显示成功反馈并自动确认
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showMapPicker = false
        }
    }
    
    private func useCurrentLocation() {
        guard locationManager.hasLocationPermission else {
            // 如果没有权限，请求权限
            locationManager.requestLocationPermission()
            return
        }
        
        isAutoLocating = true
        locationManager.requestLocation()
        
        // 延迟检查位置更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let coordinate = locationManager.currentCoordinate {
                // 设置为选中的坐标，让用户确认
                selectedCoordinate = coordinate
                selectedAddress = nil
                
                // 更新地图位置到当前位置
                let newRegion = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                region = newRegion
                mapPosition = .region(newRegion)
                
                // 获取当前位置的地址
                isGeocodingAddress = true
                reverseGeocodeCoordinate(coordinate) { addressString in
                    self.selectedAddress = addressString ?? "无法获取地址信息"
                    self.isGeocodingAddress = false
                }
                
                print("✓ 定位成功，请确认是否使用此位置")
            } else if let error = locationManager.locationError {
                print("定位失败: \(error)")
            }
            isAutoLocating = false
        }
    }
    
    // MARK: - 辅助方法
    
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