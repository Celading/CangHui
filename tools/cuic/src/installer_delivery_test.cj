package cuic

import std.fs.exists

@Test
func installerDeliveryHelpNamesExplicitPayloadAndEngine(): Unit {
    let text = helpText()
    @Expect(text.contains("cuic package installer windows"))
    @Expect(text.contains("--payload <dir>"))
    @Expect(text.contains("--engine-bundle <dir>"))
}

@Test
func installerDeliverySourceHelperDoesNotRequireConsumerFramework(): Unit {
    @Expect(exists(installerDeliveryScript()))
}
