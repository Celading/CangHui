package cui.host

@Test
func iosHostBootstrapAbiStaysStable(): Unit {
    @Expect(iosHostAbiVersion(), 1)
}
