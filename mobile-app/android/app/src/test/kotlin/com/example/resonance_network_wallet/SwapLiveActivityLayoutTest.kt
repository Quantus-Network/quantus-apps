package com.example.resonance_network_wallet

import android.widget.RemoteViews
import org.junit.Assert.assertEquals
import org.junit.Test
import org.w3c.dom.Document
import org.w3c.dom.Element
import java.io.File
import javax.xml.XMLConstants
import javax.xml.parsers.DocumentBuilderFactory

/**
 * [RemoteViews.apply] installs a [android.view.LayoutInflater.Filter] that accepts a class only
 * when it carries [RemoteViews.RemoteView]. The host unit-test `android.jar` stubs [RemoteViews.apply]
 * itself, so this runs that same filter over `swap_live_activity.xml`.
 */
class SwapLiveActivityLayoutTest {
    @Test
    fun swapLiveLayoutAllowsOnlyRemoteViewWidgets() {
        val rejected = layoutTags().filterNot(::remoteViewsAllows)
        assertEquals(emptyList<String>(), rejected)
    }

    @Test
    fun amountAndSymbolStayOnOneLine() {
        val ids = listOf("swap_live_from_amount", "swap_live_from_symbol", "swap_live_to_amount", "swap_live_to_symbol")
        val wrapping = ids.filterNot { id -> textView(id).getAttribute("android:maxLines") == "1" }
        assertEquals(emptyList<String>(), wrapping)
    }

    private fun textView(id: String): Element {
        val nodes = layout().getElementsByTagName("TextView")
        return List(nodes.length) { index -> nodes.item(index) as Element }
            .single { it.getAttribute("android:id") == "@+id/$id" }
    }

    private fun remoteViewsAllows(tag: String): Boolean {
        return viewClass(tag).isAnnotationPresent(RemoteViews.RemoteView::class.java)
    }

    private fun viewClass(tag: String): Class<*> {
        val names = if ('.' in tag) listOf(tag) else listOf("android.widget.$tag", "android.view.$tag")
        return names.firstNotNullOfOrNull { name ->
            runCatching { Class.forName(name) }.getOrNull()
        } ?: error("No framework class for <$tag>")
    }

    private fun layoutTags(): List<String> {
        val nodes = layout().getElementsByTagName("*")
        return List(nodes.length) { index -> (nodes.item(index) as Element).tagName }
    }

    private fun layout(): Document {
        val factory = DocumentBuilderFactory.newInstance()
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true)
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
        return factory.newDocumentBuilder().parse(layoutFile())
    }

    private fun layoutFile(): File {
        val relative = "src/main/res/layout/swap_live_activity.xml"
        val start = System.getProperty("user.dir") ?: error("user.dir is unset")
        var dir = File(start)
        repeat(6) {
            val candidates = listOf(
                File(dir, relative),
                File(dir, "app/$relative"),
                File(dir, "android/app/$relative"),
                File(dir, "mobile-app/android/app/$relative"),
            )
            candidates.firstOrNull { it.isFile }?.let { return it }
            dir = dir.parentFile ?: error("Could not find $relative from $start")
        }
        error("Could not find $relative from $start")
    }
}
