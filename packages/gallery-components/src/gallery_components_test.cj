package cangjiegui_gallery_components

import cui.{ComponentCompatibility, HostPlatform, HostProfile}

@Test
func galleryPackageIsPlatformNeutral(): Unit {
    let descriptor = GalleryComponentPackage().descriptor()
    @Expect(descriptor.id, "cangjiegui.gallery.common")
    match (descriptor.compatibility(HostProfile(HostPlatform.Android))) {
        case ComponentCompatibility.Compatible => @Expect(true)
        case _ => @Fail("The gallery package should remain common-source.")
    }
}

@Test
func gallerySurfaceStateCanBeOwnedByAnyHost(): Unit {
    let state = GallerySurfaceState()
    state.selectedSection.value = 2
    state.notificationsEnabled.value = false
    state.rating.value = 5
    state.page.value = 4
    @Expect(state.selectedSection.value, 2)
    @Expect(state.notificationsEnabled.value, false)
    @Expect(state.rating.value, 5)
    @Expect(state.page.value, 4)
}
