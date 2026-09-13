# ShareActivity, UrlCleaner, and ShortLinkResolver are plain Kotlin objects/classes with no
# reflection-based access (no serialization, no reflection-driven DI) -- default R8 rules from
# proguard-android-optimize.txt are sufficient. Add project-specific -keep rules here only if a
# release build breaks in a way a debug build doesn't (that's the signal something here relies on
# a name/shape R8 removed or renamed).
