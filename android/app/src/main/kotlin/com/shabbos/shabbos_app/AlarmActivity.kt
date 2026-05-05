package app.shabbos.android

import android.animation.ValueAnimator
import android.app.Activity
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.*
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.*
import android.widget.*
import kotlin.math.*

/**
 * Beautiful alarm Activity with candle flame animations matching the splash screen.
 * Sets volumeControlStream = STREAM_ALARM so hardware volume keys
 * control alarm volume during playback.
 */
class AlarmActivity : Activity() {

    companion object {
        private const val TAG = "ShabbosAlarmActivity"
        const val ACTION_ALARM_DONE = "app.shabbos.android.ALARM_DONE"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
    }

    private val animators = mutableListOf<ValueAnimator>()
    private var flameView: FlameCanvasView? = null
    private var particleView: ParticleCanvasView? = null
    private var glowView: GlowView? = null
    private var notificationId: Int = -1

    private val alarmDoneReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d(TAG, "Received ALARM_DONE broadcast, finishing activity")
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "AlarmActivity created")

        // Show over lock screen and turn screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Route hardware volume keys to the alarm stream
        volumeControlStream = AudioManager.STREAM_ALARM

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "שבת שלום!"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: ""
        notificationId = intent?.getIntExtra(EXTRA_NOTIFICATION_ID, -1) ?: -1

        buildUI(title, body)
        startAnimations()

        // Register receiver to auto-dismiss when audio completes
        val filter = IntentFilter(ACTION_ALARM_DONE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(alarmDoneReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(alarmDoneReceiver, filter)
        }
    }

    private var isSilenced = false

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (!isSilenced && (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
                            keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                            keyCode == KeyEvent.KEYCODE_HEADSETHOOK)) {
            silenceAlarm()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun silenceAlarm() {
        if (isSilenced) return
        isSilenced = true
        Log.d(TAG, "Silencing alarm via hardware key (like incoming call)")
        stopService(Intent(this, AlarmAudioService::class.java))
        cancelAlarmNotification()
        finish()
    }

    private fun cancelAlarmNotification() {
        if (notificationId != -1) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(notificationId)
            Log.d(TAG, "Cancelled alarm notification ID: $notificationId")
        }
    }

    override fun onDestroy() {
        animators.forEach { it.cancel() }
        animators.clear()
        try { unregisterReceiver(alarmDoneReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun buildUI(title: String, body: String) {
        val dark = Color.parseColor("#020204")

        // Root FrameLayout to layer background, particles, and content
        val root = FrameLayout(this).apply {
            setBackgroundColor(dark)
        }

        // Breathing background glow
        glowView = GlowView(this@AlarmActivity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        root.addView(glowView)

        // Particle overlay (smoke + embers)
        particleView = ParticleCanvasView(this@AlarmActivity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        root.addView(particleView)

        // Main content column
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(32), dp(48), dp(32), dp(40))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        // Spacer top
        content.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1.5f)
        })

        // בס״ד badge
        val bsdView = buildBsdBadge()
        content.addView(bsdView)

        // Spacer
        content.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, dp(20))
        })

        // Flame candles
        flameView = FlameCanvasView(this@AlarmActivity).apply {
            layoutParams = LinearLayout.LayoutParams(dp(200), dp(260)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
            }
        }
        content.addView(flameView)

        // Spacer
        content.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, dp(28))
        })

        // Title with gold color
        val titleView = TextView(this).apply {
            text = title
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 36f)
            setTextColor(Color.parseColor("#D4A84B"))
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            gravity = Gravity.CENTER
            setShadowLayer(30f, 0f, 0f, Color.parseColor("#80D4A84B"))
            alpha = 0f
        }
        content.addView(titleView)

        // Body text
        val bodyView = if (body.isNotEmpty()) {
            TextView(this).apply {
                text = body
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setTextColor(Color.parseColor("#99FFFFFF"))
                gravity = Gravity.CENTER
                setPadding(0, dp(8), 0, 0)
                alpha = 0f
            }
        } else null
        bodyView?.let { content.addView(it) }

        // Elegant divider
        val dividerView = buildDivider()
        dividerView.alpha = 0f
        content.addView(dividerView)

        // Volume hint
        val hintView = TextView(this).apply {
            text = "🔊  Use volume keys to adjust"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTextColor(Color.parseColor("#55FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, 0)
            letterSpacing = 0.05f
            alpha = 0f
        }
        content.addView(hintView)

        // Spacer
        content.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 2f)
        })

        // Dismiss button
        val dismissBtn = buildDismissButton()
        dismissBtn.alpha = 0f
        content.addView(dismissBtn)

        // Bottom spacer
        content.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, dp(24))
        })

        root.addView(content)

        // Vignette overlay
        root.addView(VignetteView(this@AlarmActivity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        })

        setContentView(root)

        // Choreographed entrance animations
        scheduleEntrance(bsdView, 200, 600)
        scheduleEntrance(titleView, 500, 700, slideY = 25f)
        bodyView?.let { scheduleEntrance(it, 700, 600) }
        scheduleEntrance(dividerView, 900, 500)
        scheduleEntrance(hintView, 1000, 500)
        scheduleEntrance(dismissBtn, 1200, 600, slideY = 20f)
    }

    private fun buildBsdBadge(): TextView {
        val gold = Color.parseColor("#D4A84B")
        val badge = TextView(this).apply {
            text = "בס״ד"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(gold)
            letterSpacing = 0.15f
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(6), dp(16), dp(6))
            alpha = 0f
        }
        val border = android.graphics.drawable.GradientDrawable().apply {
            setStroke(1, Color.argb(100, 212, 168, 75))
            cornerRadius = dp(16).toFloat()
            setColor(Color.TRANSPARENT)
        }
        badge.background = border
        badge.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { gravity = Gravity.CENTER_HORIZONTAL }
        return badge
    }

    private fun buildDivider(): LinearLayout {
        val gold40 = Color.argb(100, 212, 168, 75)
        val goldFull = Color.parseColor("#D4A84B")

        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, 0)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.CENTER_HORIZONTAL }

            // Left line
            addView(View(this@AlarmActivity).apply {
                layoutParams = LinearLayout.LayoutParams(dp(50), dp(1))
                background = android.graphics.drawable.GradientDrawable(
                    android.graphics.drawable.GradientDrawable.Orientation.LEFT_RIGHT,
                    intArrayOf(Color.TRANSPARENT, gold40)
                )
            })

            // Diamond
            addView(View(this@AlarmActivity).apply {
                layoutParams = LinearLayout.LayoutParams(dp(6), dp(6)).apply {
                    setMargins(dp(12), 0, dp(12), 0)
                }
                setBackgroundColor(goldFull)
                rotation = 45f
            })

            // Right line
            addView(View(this@AlarmActivity).apply {
                layoutParams = LinearLayout.LayoutParams(dp(50), dp(1))
                background = android.graphics.drawable.GradientDrawable(
                    android.graphics.drawable.GradientDrawable.Orientation.LEFT_RIGHT,
                    intArrayOf(gold40, Color.TRANSPARENT)
                )
            })
        }
    }

    private fun buildDismissButton(): FrameLayout {
        val gold = Color.parseColor("#E8B923")
        val dark = Color.parseColor("#1A1A1A")

        val wrapper = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.CENTER_HORIZONTAL }
        }

        val btn = TextView(this).apply {
            text = "שקט  ✦  Silence"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(dark)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(dp(52), dp(14), dp(52), dp(14))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(gold)
                cornerRadius = dp(12).toFloat()
            }
            isClickable = true
            isFocusable = true
            setOnClickListener {
                Log.d(TAG, "Good Shabbos button pressed, stopping audio service")
                stopService(Intent(this@AlarmActivity, AlarmAudioService::class.java))
                cancelAlarmNotification()
                finish()
            }
        }
        wrapper.addView(btn)
        return wrapper
    }

    private fun scheduleEntrance(view: View, delayMs: Long, durationMs: Long, slideY: Float = 0f) {
        view.postDelayed({
            view.translationY = slideY
            view.animate()
                .alpha(1f)
                .translationY(0f)
                .setDuration(durationMs)
                .setInterpolator(DecelerateInterpolator(2f))
                .start()
        }, delayMs)
    }

    private fun startAnimations() {
        // Flame animation (two independent frequencies like splash)
        val flame1Anim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 800
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            interpolator = LinearInterpolator()
            addUpdateListener { flameView?.flame1Phase = it.animatedValue as Float; flameView?.invalidate() }
        }

        val flame2Anim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1100
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            interpolator = LinearInterpolator()
            addUpdateListener { flameView?.flame2Phase = it.animatedValue as Float }
        }

        val flickerAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 150
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            interpolator = LinearInterpolator()
            addUpdateListener { flameView?.flickerPhase = it.animatedValue as Float }
        }

        // Glow pulse (breathing effect)
        val glowAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 3000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener {
                val v = it.animatedValue as Float
                flameView?.glowIntensity = v
                glowView?.intensity = v
                glowView?.invalidate()
            }
        }

        // Background breathing
        val breatheAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 5000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener { glowView?.breathe = it.animatedValue as Float }
        }

        // Particle animation
        val particleAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 8000
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener {
                particleView?.progress = it.animatedValue as Float
                particleView?.invalidate()
            }
        }

        animators.addAll(listOf(flame1Anim, flame2Anim, flickerAnim, glowAnim, breatheAnim, particleAnim))
        animators.forEach { it.start() }
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics
        ).toInt()
    }

    // ─────────────────────────────────────────────────────────────
    // Custom Views
    // ─────────────────────────────────────────────────────────────

    /**
     * Breathing background radial glow (matches splash's _buildAnimatedBackground)
     */
    class GlowView(context: Context) : View(context) {
        var intensity = 0f
        var breathe = 0f

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f
            val cy = h * 0.35f + breathe * h * 0.02f

            val warmDark = lerpColor(0xFF1A0D02.toInt(), 0xFF251205.toInt(), intensity)
            val colors = intArrayOf(warmDark, 0xFF0A0505.toInt(), 0xFF020204.toInt())
            val stops = floatArrayOf(0f, 0.4f, 1f)

            val shader = RadialGradient(cx, cy, h * 0.9f, colors, stops, Shader.TileMode.CLAMP)
            val paint = Paint().apply { this.shader = shader }
            canvas.drawRect(0f, 0f, w, h, paint)
        }

        private fun lerpColor(c1: Int, c2: Int, t: Float): Int {
            val a = lerp(Color.alpha(c1), Color.alpha(c2), t)
            val r = lerp(Color.red(c1), Color.red(c2), t)
            val g = lerp(Color.green(c1), Color.green(c2), t)
            val b = lerp(Color.blue(c1), Color.blue(c2), t)
            return Color.argb(a, r, g, b)
        }

        private fun lerp(a: Int, b: Int, t: Float): Int = (a + (b - a) * t).toInt()
    }

    /**
     * Two realistic candle flames with wicks, candle bodies, and brass holders.
     * Matches splash's _RealisticFlamePainter + _buildSingleCandle.
     */
    class FlameCanvasView(context: Context) : View(context) {
        var flame1Phase = 0f
        var flame2Phase = 0f
        var flickerPhase = 0f
        var glowIntensity = 0f

        private val flamePaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f

            // Ambient glow on surface
            drawAmbientGlow(canvas, cx, h, w)

            // Central glow orb
            drawGlowOrb(canvas, cx, h * 0.42f, w)

            // Left candle
            val leftX = cx - w * 0.14f
            drawCandle(canvas, leftX, h, flame1Phase, flickerPhase, 1, h * 0.36f)

            // Right candle
            val rightX = cx + w * 0.14f
            drawCandle(canvas, rightX, h, flame2Phase, 1f - flickerPhase, 2, h * 0.34f)
        }

        private fun drawAmbientGlow(canvas: Canvas, cx: Float, h: Float, w: Float) {
            val alpha = (40 + glowIntensity * 20).toInt()
            glowPaint.shader = RadialGradient(
                cx, h - dp(8), w * 0.5f,
                intArrayOf(Color.argb(alpha, 255, 149, 0), Color.TRANSPARENT),
                null, Shader.TileMode.CLAMP
            )
            canvas.drawOval(cx - w * 0.45f, h - dp(24), cx + w * 0.45f, h, glowPaint)
        }

        private fun drawGlowOrb(canvas: Canvas, cx: Float, cy: Float, w: Float) {
            val size = w * 0.45f + glowIntensity * w * 0.08f
            val a1 = (30 + glowIntensity * 15).toInt()
            val a2 = (13).toInt()
            glowPaint.shader = RadialGradient(
                cx, cy, size,
                intArrayOf(Color.argb(a1, 255, 170, 51), Color.argb(a2, 255, 102, 0), Color.TRANSPARENT),
                floatArrayOf(0f, 0.5f, 1f), Shader.TileMode.CLAMP
            )
            canvas.drawCircle(cx, cy, size, glowPaint)
        }

        private fun drawCandle(canvas: Canvas, cx: Float, baseH: Float, flamePhase: Float, flicker: Float, seed: Int, candleBodyH: Float) {
            // Natural flame movement (multi-frequency like splash)
            val primary = sin(flamePhase * PI).toFloat()
            val secondary = sin(flamePhase * PI * 2.3 + seed).toFloat() * 0.3f
            val micro = sin(flicker * PI * 4.0).toFloat() * 0.15f
            val combined = (primary + secondary + micro).coerceIn(0f, 1f)
            val sway = sin(flamePhase * PI + seed).toFloat() * dp(2)

            val candleW = dp(18).toFloat()
            val holderH = dp(22).toFloat()
            val wickH = dp(7).toFloat()
            val flameH = dp(70).toFloat()

            val bodyTop = baseH - holderH - candleBodyH
            val wickTop = bodyTop - wickH
            val flameBase = wickTop

            // Brass holder
            drawBrassHolder(canvas, cx, baseH - holderH, candleW, holderH)

            // Candle body
            drawCandleBody(canvas, cx, bodyTop, candleW, candleBodyH)

            // Wax drips
            drawWaxDrips(canvas, cx, bodyTop, candleW, combined)

            // Melted wax pool
            drawWaxPool(canvas, cx, bodyTop, candleW)

            // Wick
            flamePaint.shader = null
            val wickW = dp(2).toFloat()
            flamePaint.shader = LinearGradient(
                cx, wickTop, cx, wickTop + wickH,
                intArrayOf(0xFF1A1A1A.toInt(), 0xFF2D2518.toInt(), 0xFF3D3025.toInt()),
                null, Shader.TileMode.CLAMP
            )
            canvas.drawRect(cx - wickW / 2, wickTop, cx + wickW / 2, wickTop + wickH, flamePaint)

            // Flames (3 layers like splash)
            drawFlame(canvas, cx + sway, flameBase, flameH, combined, sway, seed)
        }

        private fun drawFlame(canvas: Canvas, cx: Float, baseY: Float, flameH: Float, phase: Float, sway: Float, seed: Int) {
            // Outer flame (orange/red)
            val outerW = dp(12) + phase * dp(3)
            val outerH = dp(45) + phase * dp(10)
            val outerPath = Path().apply {
                moveTo(cx, baseY)
                quadTo(cx - outerW - sway, baseY - outerH * 0.4f, cx - outerW * 0.3f + sway, baseY - outerH * 0.75f)
                quadTo(cx + sway * 0.5f, baseY - outerH - phase * dp(4), cx + outerW * 0.3f + sway, baseY - outerH * 0.75f)
                quadTo(cx + outerW - sway, baseY - outerH * 0.4f, cx, baseY)
                close()
            }
            flamePaint.shader = LinearGradient(
                cx, baseY, cx, baseY - outerH,
                intArrayOf(0xFFFFAA33.toInt(), 0xFFFF7700.toInt(), Color.argb(200, 255, 68, 0), Color.argb(75, 204, 34, 0), Color.TRANSPARENT),
                floatArrayOf(0f, 0.25f, 0.5f, 0.75f, 1f), Shader.TileMode.CLAMP
            )
            canvas.drawPath(outerPath, flamePaint)

            // Middle flame (yellow/orange)
            val midW = dp(8) + phase * dp(2)
            val midH = dp(35) + phase * dp(7)
            val midPath = Path().apply {
                moveTo(cx, baseY - dp(2))
                quadTo(cx - midW - sway * 0.7f, baseY - dp(2) - midH * 0.45f, cx + sway * 0.3f, baseY - dp(2) - midH)
                quadTo(cx + midW - sway * 0.7f, baseY - dp(2) - midH * 0.45f, cx, baseY - dp(2))
                close()
            }
            flamePaint.shader = LinearGradient(
                cx, baseY, cx, baseY - midH,
                intArrayOf(0xFFFFDD66.toInt(), 0xFFFFBB33.toInt(), Color.argb(150, 255, 136, 0), Color.TRANSPARENT),
                floatArrayOf(0f, 0.35f, 0.7f, 1f), Shader.TileMode.CLAMP
            )
            canvas.drawPath(midPath, flamePaint)

            // Inner flame (white/yellow core)
            val innerW = dp(4) + phase * dp(1.5f)
            val innerH = dp(20) + phase * dp(5)
            val innerPath = Path().apply {
                moveTo(cx, baseY - dp(3))
                quadTo(cx - innerW, baseY - dp(3) - innerH * 0.5f, cx + sway * 0.2f, baseY - dp(3) - innerH)
                quadTo(cx + innerW, baseY - dp(3) - innerH * 0.5f, cx, baseY - dp(3))
                close()
            }
            flamePaint.shader = LinearGradient(
                cx, baseY, cx, baseY - innerH,
                intArrayOf(0xFFFFFFF8.toInt(), 0xFFFFFFE0.toInt(), Color.argb(200, 255, 238, 170), Color.TRANSPARENT),
                floatArrayOf(0f, 0.3f, 0.6f, 1f), Shader.TileMode.CLAMP
            )
            canvas.drawPath(innerPath, flamePaint)

            // Bright core spot
            val corePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(230, 255, 255, 255)
                maskFilter = BlurMaskFilter(dp(3).toFloat(), BlurMaskFilter.Blur.NORMAL)
            }
            canvas.drawOval(cx - dp(3), baseY - dp(10), cx + dp(3), baseY - dp(4), corePaint)
        }

        private fun drawCandleBody(canvas: Canvas, cx: Float, top: Float, w: Float, h: Float) {
            flamePaint.shader = LinearGradient(
                cx - w / 2, top, cx + w / 2, top,
                intArrayOf(0xFFD8CDB8.toInt(), 0xFFF0E8D8.toInt(), 0xFFFFFBF2.toInt(), 0xFFFFF8E8.toInt(), 0xFFF5ECD8.toInt(), 0xFFE8DCC8.toInt()),
                floatArrayOf(0f, 0.15f, 0.35f, 0.65f, 0.85f, 1f), Shader.TileMode.CLAMP
            )
            canvas.drawRoundRect(cx - w / 2, top, cx + w / 2, top + h, dp(2).toFloat(), dp(2).toFloat(), flamePaint)

            // Warm glow shadow around candle
            val glowP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb((65 + glowIntensity * 40).toInt(), 255, 136, 0)
                maskFilter = BlurMaskFilter(dp(20).toFloat(), BlurMaskFilter.Blur.NORMAL)
            }
            canvas.drawRoundRect(cx - w / 2 - dp(4), top, cx + w / 2 + dp(4), top + h, dp(4).toFloat(), dp(4).toFloat(), glowP)
            // Redraw body on top of glow
            canvas.drawRoundRect(cx - w / 2, top, cx + w / 2, top + h, dp(2).toFloat(), dp(2).toFloat(), flamePaint)
        }

        private fun drawWaxPool(canvas: Canvas, cx: Float, bodyTop: Float, candleW: Float) {
            val poolW = candleW * 1.1f
            val poolH = dp(4).toFloat()
            flamePaint.shader = RadialGradient(
                cx, bodyTop, poolW / 2,
                intArrayOf(0xFFFFF8E8.toInt(), 0xFFF5ECD8.toInt()),
                null, Shader.TileMode.CLAMP
            )
            canvas.drawOval(cx - poolW / 2, bodyTop - poolH / 2, cx + poolW / 2, bodyTop + poolH / 2, flamePaint)
        }

        private fun drawWaxDrips(canvas: Canvas, cx: Float, bodyTop: Float, candleW: Float, phase: Float) {
            flamePaint.shader = null
            flamePaint.color = Color.argb(180, 255, 253, 245)
            // Left drip
            val dripW = dp(4).toFloat()
            val dripH = dp(14) + phase * dp(3)
            canvas.drawRoundRect(
                cx - candleW / 2 + dp(1), bodyTop,
                cx - candleW / 2 + dp(1) + dripW, bodyTop + dripH,
                dripW / 2, dripW / 2, flamePaint
            )
            // Right drip
            flamePaint.color = Color.argb(130, 248, 240, 224)
            val dripH2 = dp(10) + phase * dp(2)
            canvas.drawRoundRect(
                cx + candleW / 2 - dp(1) - dp(3), bodyTop + dp(6),
                cx + candleW / 2 - dp(1), bodyTop + dp(6) + dripH2,
                dp(2).toFloat(), dp(2).toFloat(), flamePaint
            )
        }

        private fun drawBrassHolder(canvas: Canvas, cx: Float, top: Float, candleW: Float, h: Float) {
            val lipW = candleW * 1.5f
            val lipH = h * 0.22f
            val cupW = candleW * 1.3f
            val cupH = h * 0.42f
            val baseW = candleW * 1.8f
            val baseH = h * 0.36f

            // Lip
            flamePaint.shader = LinearGradient(cx, top, cx, top + lipH,
                intArrayOf(0xFFD4A84B.toInt(), 0xFFB8923D.toInt()), null, Shader.TileMode.CLAMP)
            canvas.drawRoundRect(cx - lipW / 2, top, cx + lipW / 2, top + lipH, dp(2).toFloat(), dp(2).toFloat(), flamePaint)

            // Cup
            flamePaint.shader = LinearGradient(cx - cupW / 2, top + lipH, cx + cupW / 2, top + lipH,
                intArrayOf(0xFF8B6914.toInt(), 0xFFB8923D.toInt(), 0xFFD4A84B.toInt(), 0xFFB8923D.toInt(), 0xFF8B6914.toInt()),
                floatArrayOf(0f, 0.25f, 0.5f, 0.75f, 1f), Shader.TileMode.CLAMP)
            canvas.drawRect(cx - cupW / 2, top + lipH, cx + cupW / 2, top + lipH + cupH, flamePaint)

            // Base
            flamePaint.shader = LinearGradient(cx, top + lipH + cupH, cx, top + h,
                intArrayOf(0xFFB8923D.toInt(), 0xFF8B6914.toInt(), 0xFF6B5210.toInt()), null, Shader.TileMode.CLAMP)
            canvas.drawRoundRect(cx - baseW / 2, top + lipH + cupH, cx + baseW / 2, top + h, dp(3).toFloat(), dp(3).toFloat(), flamePaint)
        }

        private fun dp(value: Int): Float {
            return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics)
        }

        private fun dp(value: Float): Float {
            return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics)
        }
    }

    /**
     * Smoke wisps and ember particles (matches splash's _SmokeParticlePainter)
     */
    class ParticleCanvasView(context: Context) : View(context) {
        var progress = 0f
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val random = java.util.Random(42)

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            val seeds = generateSeeds()

            // Smoke wisps
            for (i in 0 until 15) {
                val s = seeds[i]
                val baseX = w * 0.4f + s.rx * w * 0.2f
                val baseY = h * 0.32f
                val speed = 0.15f + s.ry * 0.25f
                val pp = (progress * speed + i * 0.06f) % 1f

                val drift = sin(pp * PI * 3 + i * 0.5).toFloat() * dp(20)
                val x = baseX + drift
                val y = baseY - pp * h * 0.25f

                val fadeIn = if (pp < 0.15f) pp / 0.15f else 1f
                val fadeOut = if (pp > 0.6f) (1f - pp) / 0.4f else 1f
                val alpha = (fadeIn * fadeOut * 0.15f * 255).toInt().coerceIn(0, 255)

                paint.color = Color.argb(alpha, 255, 255, 255)
                paint.maskFilter = BlurMaskFilter(dp(6), BlurMaskFilter.Blur.NORMAL)
                canvas.drawCircle(x, y, dp(3) + s.rx * dp(4) + pp * dp(5), paint)
            }

            // Ember sparks
            paint.maskFilter = null
            for (i in 0 until 20) {
                val s = seeds[15 + i]
                val baseX = w * 0.35f + s.rx * w * 0.3f
                val baseY = h * 0.35f
                val speed = 0.3f + s.ry * 0.5f
                val pp = (progress * speed + i * 0.04f) % 1f

                val wobble = sin(pp * PI * 5 + i).toFloat() * dp(10)
                val x = baseX + wobble
                val y = baseY - pp * h * 0.2f

                val fadeIn = if (pp < 0.1f) pp / 0.1f else 1f
                val fadeOut = if (pp > 0.7f) (1f - pp) / 0.3f else 1f
                val alpha = (fadeIn * fadeOut * (0.3f + s.rx * 0.4f) * 255).toInt().coerceIn(0, 255)

                val r = (255 * (1f - s.ry * 0.3f)).toInt()
                val g = (170 + s.ry * 50).toInt()
                val b = (51 + s.ry * 85).toInt()
                paint.color = Color.argb(alpha, r, g, b)
                canvas.drawCircle(x, y, dp(1) + s.rx * dp(1), paint)
            }
        }

        private data class Seed(val rx: Float, val ry: Float)

        private fun generateSeeds(): List<Seed> {
            random.setSeed(42)
            return (0 until 35).map { Seed(random.nextFloat(), random.nextFloat()) }
        }

        private fun dp(value: Int): Float {
            return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics)
        }
    }

    /**
     * Vignette overlay (matches splash's _buildVignette)
     */
    class VignetteView(context: Context) : View(context) {
        private val paint = Paint()

        override fun onDraw(canvas: Canvas) {
            val cx = width / 2f
            val cy = height / 2f
            val radius = max(width, height) * 0.8f
            paint.shader = RadialGradient(
                cx, cy, radius,
                intArrayOf(Color.TRANSPARENT, Color.argb(100, 0, 0, 0), Color.argb(200, 0, 0, 0)),
                floatArrayOf(0.3f, 0.75f, 1f), Shader.TileMode.CLAMP
            )
            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        }
    }
}
