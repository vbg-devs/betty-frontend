package social.betty.app

import android.app.Application
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.decode.SvgDecoder

class BettyApplication : Application(), ImageLoaderFactory {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }

    /**
     * App-wide Coil loader. National-team flags resolve to remote `.svg` URLs
     * (`https://betty.social/flags/<key>.svg`, the same assets the web client serves),
     * which Coil's default decoders can't read — so register [SvgDecoder]. Without it the
     * flag images fail to decode silently and team logos render as empty circles.
     */
    override fun newImageLoader(): ImageLoader =
        ImageLoader.Builder(this)
            .components { add(SvgDecoder.Factory()) }
            .build()
}
