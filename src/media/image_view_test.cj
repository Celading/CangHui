package chui.media

import sdl.{Rect, Renderer, Size}
import chui.core.{LengthUnits, Theme, UiContext, designComputedCategoryName}
import chui.system.{ApplicationResourceReceipt, ApplicationResourceRole, ApplicationResourceRootKind}

@Test
func imageViewMeasuresAndClosesWithoutLoadingTexture(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let image = ImageView("missing.bmp", preferredHeight: 96.vp)

    let measured = image.measure(ctx, Size(240.0, 40.0))
    image.close()
    image.close()

    @Expect(measured.w, Float32(240.0))
    @Expect(measured.h, Float32(40.0))
    @Expect(image.isClosed())
}

@Test
func imageViewExportsLogicalResourceIdentityWithoutPhysicalPath(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let receipt = ApplicationResourceReceipt("hero", ApplicationResourceRole.Data,
        "/private/build/assets/hero.png", ApplicationResourceRootKind.Source)
    let image = ImageView.fromResource(receipt, fit: ImageFit.Cover)
    let facts = image.designComputedFacts(ctx)
    var json = ""
    for (fact in facts) { json += fact.toJson() }
    @Expect(json.contains("resource.name"))
    @Expect(json.contains("hero"))
    @Expect(json.contains("image.fit"))
    @Expect(json.contains("cover"))
    @Expect(!json.contains("/private/build"))
    @Expect(designComputedCategoryName(facts[0].category), "resource")
    image.layout(ctx, Rect(4.0, 6.0, 120.0, 80.0))
    image.draw(ctx)
    let draw = renderer.drawIr()
    @Expect(draw.size, 1)
    @Expect(draw[0].kind, "resource.image")
    @Expect(draw[0].data.contains("\"name\":\"hero\""))
    @Expect(!draw[0].data.contains("/private/build"))
}
