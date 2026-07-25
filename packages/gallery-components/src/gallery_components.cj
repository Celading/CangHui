package cangjiegui_gallery_components

import cui.*

public class GalleryComponentPackage <: ComponentPackage {
    public func descriptor(): ComponentPackageDescriptor {
        galleryPackageDescriptor()
    }
}

public func galleryPackageDescriptor(): ComponentPackageDescriptor {
    ComponentPackageDescriptor(
        "cangjiegui.gallery.common",
        "CangjieGUI Gallery Common Components",
        "0.1.0"
    )
}

/** State owned by the consumer and retained while the viewport changes. */
public class GallerySurfaceState {
    public let selectedSection = State<Int64>(0)
    public let notificationsEnabled = State<Bool>(true)
    public let overviewProgress = State<Float32>(0.68)
    public let activityProgress = State<Float32>(0.42)
}

/** One component tree rendered unchanged for compact, medium and expanded hosts. */
public func galleryCommonSurface(context: ComponentContext, state: GallerySurfaceState): Unit {
    match (context.viewport.widthClass()) {
        case ViewportClass.Compact => compactSurface(context, state)
        case ViewportClass.Medium => mediumSurface(context, state)
        case ViewportClass.Expanded => expandedSurface(context, state)
    }
}

private func compactSurface(context: ComponentContext, state: GallerySurfaceState): Unit {
    VStack {
        surfaceHeader(context)
        SegmentedControl(["Overview", "Activity", "Settings"], state.selectedSection, id: "gallery-mobile-sections")
        Divider()
        primaryContent(state)
    }.spacing(14.vp).padding(18.vp)
}

private func mediumSurface(context: ComponentContext, state: GallerySurfaceState): Unit {
    VStack {
        HStack {
            surfaceHeader(context)
            Spacer()
            Button("Create", {=> state.selectedSection.value = 1})
        }.hug()
        SegmentedControl(["Overview", "Activity", "Settings"], state.selectedSection, id: "gallery-tablet-sections")
        Divider()
        primaryContent(state)
    }.spacing(16.vp).padding(22.vp)
}

private func expandedSurface(context: ComponentContext, state: GallerySurfaceState): Unit {
    HStack {
        VStack {
            Label("CangjieGUI", fontSize: 20.fp)
            Label(hostPlatformName(context.host.platform), muted: true)
            Divider()
            Button("Overview", {=> state.selectedSection.value = 0})
            Button("Activity", {=> state.selectedSection.value = 1})
            Button("Settings", {=> state.selectedSection.value = 2})
            Spacer()
            Label("Common package 0.1.0", muted: true)
        }.spacing(10.vp).hug().padding(20.vp).width(230.vp)
        Divider()
        VStack {
            HStack {
                surfaceHeader(context)
                Spacer()
                Button("Create", {=> state.selectedSection.value = 1})
            }.hug()
            Divider()
            primaryContent(state)
        }.spacing(18.vp).padding(24.vp)
    }.spacing(0.vp)
}

private func surfaceHeader(context: ComponentContext): Unit {
    VStack {
        Label(sectionTitle(context.viewport.widthClass()), fontSize: 22.fp)
        Label("${context.viewport.label} / ${hostPlatformName(context.host.platform)}", muted: true)
    }.spacing(2.vp).hug()
}

private func primaryContent(state: GallerySurfaceState): Unit {
    match (state.selectedSection.value) {
        case 1 => activityContent(state.activityProgress)
        case 2 => settingsContent(state.notificationsEnabled)
        case _ => overviewContent(state.overviewProgress)
    }
}

private func overviewContent(progress: Observable<Float32>): Unit {
    VStack {
        Label("Today", fontSize: 18.fp)
        Label("Three common tasks are ready across the current viewport.", muted: true).wrap()
        ProgressBar(progress)
        HStack {
            Button("Continue", {=> ()})
            Button("Details", {=> ()})
        }.hug()
        Divider()
        Label("Recent")
        Label("Component package metadata", muted: true)
        Label("Responsive common layout", muted: true)
        Label("Desktop preview matrix", muted: true)
    }.spacing(12.vp)
}

private func activityContent(progress: Observable<Float32>): Unit {
    VStack {
        Label("Activity", fontSize: 18.fp)
        Label("The desktop gallery mounted the same typed package intended for platform hosts.", muted: true).wrap()
        ProgressBar(progress)
        Label("Package compatibility checked", muted: true)
        Label("Responsive layout selected", muted: true)
        Label("Host-specific services remain outside common UI", muted: true).wrap()
    }.spacing(12.vp)
}

private func settingsContent(notificationsEnabled: Bindable<Bool>): Unit {
    VStack {
        Label("Settings", fontSize: 18.fp)
        Switch("Notifications", notificationsEnabled)
        Label("The common component owns presentation state only.", muted: true).wrap()
        Label("Secure storage, lifecycle and media stay in the host.", muted: true).wrap()
    }.spacing(12.vp)
}

private func sectionTitle(viewportClass: ViewportClass): String {
    match (viewportClass) {
        case ViewportClass.Compact => "Compact common"
        case ViewportClass.Medium => "Medium common"
        case ViewportClass.Expanded => "Expanded common"
    }
}
