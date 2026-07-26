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
    public let architectureChip = State<Bool>(true)
    public let toolingChip = State<Bool>(false)
    public let rating = State<Int64>(4)
    public let page = State<Int64>(2)
    public let step = State<Int64>(1)
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
        SegmentedControl(["Components", "Activity", "Settings"], state.selectedSection, key: "gallery-mobile-sections")
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
        SegmentedControl(["Components", "Activity", "Settings"], state.selectedSection, key: "gallery-tablet-sections")
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
            Button("Components", {=> state.selectedSection.value = 0})
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
        case _ => componentContent(state)
    }
}

private func componentContent(state: GallerySurfaceState): Unit {
    VStack {
        HStack {
            Label("ArkUI-aligned controls", fontSize: 18.fp)
            Spacer()
            Badge("upstream 0.9.2", kind: BadgeKind.Info)
        }.hug()
        Breadcrumb(["CangjieGUI", "Common", "Controls"], maxItems: 3)
        HStack {
            Badge("stable", kind: BadgeKind.Success)
            Badge("interactive", kind: BadgeKind.Accent)
            Badge("desktop proof", kind: BadgeKind.Warning)
        }.spacing(8.vp).hug()
        HStack {
            Chip("Architecture", state.architectureChip, key: "gallery-chip-architecture")
            Chip("Tooling", state.toolingChip, key: "gallery-chip-tooling")
            Spacer()
            Rating(state.rating, key: "gallery-rating")
        }.spacing(8.vp).hug()
        HStack {
            ProgressRing(state.overviewProgress.value, diameter: 68.0, thickness: 7.0)
            VStack {
                Label("Coverage progress")
                ProgressBar(state.overviewProgress)
                Label("Geometry, state, focus and pointer paths are mounted.", muted: true).wrap()
            }.spacing(8.vp)
        }.spacing(16.vp).hug()
        Pagination(8, state.page, key: "gallery-pagination")
        StepIndicator(["Pull", "Merge", "Prove"], state.step.value,
            onSelect: {index => state.step.value = index}, key: "gallery-steps")
        Divider()
        Accordion([
            AccordionSection("Interaction contract") {=>
                Label("Tab focus, pointer feedback and bounded layout stay inside the common package.", muted: true).wrap()
            },
            AccordionSection("Platform boundary") {=>
                Label("Host lifecycle, secure storage and native media remain adapter-owned.", muted: true).wrap()
            }
        ], single: true, initiallyExpanded: [0], key: "gallery-accordion")
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
