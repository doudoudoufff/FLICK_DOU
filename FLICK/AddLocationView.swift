import SwiftUI
import MapKit
import CoreLocation

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    
    @State private var name = ""
    @State private var type = LocationType.exterior
    @State private var status = LocationStatus.pending
    @State private var address = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var notes = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    
    // 地图相关状态
    @State private var showMapPicker = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMapItem: MKMapItem?
    @State private var isSearching = false
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9087, longitude: 116.3975),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9087, longitude: 116.3975),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))
    @StateObject private var locationManager = LocationManager()
    
    private var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
    
    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
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
                        TextField("", text: $name)
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
                                        type = locationType
                                    }) {
                                        Text(locationType.rawValue)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(type == locationType ? project.color : Color(.systemGray5))
                                            .foregroundColor(type == locationType ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    TextField("详细地址", text: $address)
                }
                
                // 位置信息部分
                Section("位置定位") {
                    // 显示当前坐标状态
                    HStack {
                        Text("定位状态")
                        Spacer()
                        Text(hasCoordinates ? "已设置" : "未设置")
                            .foregroundStyle(hasCoordinates ? .green : .secondary)
                    }
                    
                    // 地图设置按钮
                    Button {
                        searchText = address
                        showMapPicker = true
                    } label: {
                        Label("设置地图位置", systemImage: "map")
                    }
                    
                    // 如果已设置位置，添加清除选项
                    if hasCoordinates {
                        Button(role: .destructive) {
                            latitude = nil
                            longitude = nil
                        } label: {
                            Label("清除位置信息", systemImage: "xmark.circle")
                        }
                    }
                }
                
                Section(header: Text("联系方式")) {
                    TextField("联系人", text: $contactName)
                    TextField("联系电话", text: $contactPhone)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("备注")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("添加场地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveLocation()
                    }
                    .disabled(!isValid)
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
                            if let coordinate = coordinate {
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
                                if let coordinate = coordinate {
                                    Marker("所选位置", coordinate: coordinate)
                                        .tint(.red)
                                }
                            }
                            .overlay(alignment: .center) {
                                // 长按时的视觉指示
                                if hasCoordinates {
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
                                        
                                        if hasCoordinates {
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
                                if hasCoordinates {
                                    Text("已选择位置：\(address.isEmpty ? "未知地址" : address)")
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
                            
                            // 点击选择位置
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
    
    private var isValid: Bool {
        !name.isEmpty  // 只要求场地名称必填
    }
    
    private func saveLocation() {
        let location = Location(
            name: name,
            type: type,
            status: status,
            address: address,
            latitude: latitude,
            longitude: longitude,
            contactName: contactName.isEmpty ? nil : contactName,
            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
            notes: notes.isEmpty ? nil : notes
        )
        
        projectStore.addLocation(location, to: project)
        dismiss()
    }
    
    // MARK: - 地图相关方法
    
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
        
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        
        // 更新地址
        if let name = item.name, !name.isEmpty,
           let detailedAddress = formatDetailedAddress(for: item) {
            address = "\(name), \(detailedAddress)"
        } else if let detailedAddress = formatDetailedAddress(for: item) {
            address = detailedAddress
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
        latitude = actualLatitude
        longitude = actualLongitude
        
        print("用户点击位置: 屏幕坐标(\(tapLocation.x), \(tapLocation.y))")
        print("转换后的地图坐标: 纬度 \(actualLatitude), 经度 \(actualLongitude)")
        
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
                    self.address = formattedAddress
                    print("获取到地址: \(formattedAddress)")
                }
            }
        }
    }
    
    private func useCurrentLocation() {
        locationManager.requestLocation()
        
        // 使用 locationManager 的位置
        if let coordinate = locationManager.location?.coordinate {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            
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
                
                let formattedAddress = addressComponents.joined(separator: ", ")
                
                if !formattedAddress.isEmpty {
                    address = formattedAddress
                    
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