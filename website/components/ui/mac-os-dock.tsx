"use client"

import type React from "react"
import { useCallback, useEffect, useRef, useState } from "react"
import { cn } from "@/lib/utils"

interface DockApp {
  id: string
  name: string
  icon?: string
  /** Custom node rendered in place of the <img> (fills the scaled box). */
  content?: React.ReactNode
}

interface MacOSDockProps {
  apps: DockApp[]
  /** Receives the clicked app id plus the clicked icon's live bounding rect
   *  (for anchoring a popover to the icon). */
  onAppClick: (appId: string, rect: DOMRect | null) => void
  openApps?: string[]
  className?: string
}

/* One Dock look for every Dock on the site (hero, the intro's two, the Ghost card's ⌘Tab HUD).
   It follows the theme like the system's: light frosted glass in light, dark glass in dark. */
export const dockGlass =
  "border border-black/[0.08] bg-white/70 shadow-[inset_0_1px_0_rgba(255,255,255,0.6),0_2px_6px_rgba(0,0,0,0.06),0_12px_32px_rgba(0,0,0,0.14)] backdrop-blur-xl dark:border-white/15 dark:bg-[rgba(45,45,45,0.8)] dark:shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_8px_24px_rgba(0,0,0,0.35)]"
/** The Dock's name label, light or dark with the theme. */
export const dockTooltip =
  "rounded-md border border-black/10 bg-white/90 px-2 py-1 font-ui text-xs font-medium text-zinc-900 shadow-md backdrop-blur-sm dark:border-white/10 dark:bg-zinc-900/85 dark:text-white"
/** The open dot under an icon: dark on light glass, light on dark. */
export const dockDot = "bg-black/60 dark:bg-white/80"
/** An icon's lift off the Dock: 0.2 vanishes on dark glass, so dark takes 0.4. */
export const dockLift = "drop-shadow-[0_1px_2px_rgba(0,0,0,0.2)] dark:drop-shadow-[0_1px_2px_rgba(0,0,0,0.4)]"

// The server has no viewport, so SSR renders at this default. The client MUST
// also start here, or hydration desyncs icon *size* (the SSR value, baked into
// the server HTML) from icon *positions* (recomputed from the client viewport),
// leaving every icon overlapping. The mount effect adopts the real viewport
// once, after hydration.
const SSR_DEFAULT_CONFIG = { baseIconSize: 64, maxScale: 1.6, effectWidth: 240 }

const MacOSDock: React.FC<MacOSDockProps> = ({
  apps,
  onAppClick,
  openApps = [],
  className = "",
}) => {
  const [mouseX, setMouseX] = useState<number | null>(null)
  const [currentScales, setCurrentScales] = useState<number[]>(apps.map(() => 1))
  const [currentPositions, setCurrentPositions] = useState<number[]>([])
  const dockRef = useRef<HTMLDivElement>(null)
  const iconRefs = useRef<(HTMLElement | null)[]>([])
  const animationFrameRef = useRef<number | undefined>(undefined)
  const lastMouseMoveTime = useRef<number>(0)

  const getResponsiveConfig = useCallback(() => {
    if (typeof window === "undefined") {
      return SSR_DEFAULT_CONFIG
    }

    const smallerDimension = Math.min(window.innerWidth, window.innerHeight)

    if (smallerDimension < 480) {
      return {
        baseIconSize: Math.max(40, smallerDimension * 0.08),
        maxScale: 1.4,
        effectWidth: smallerDimension * 0.4,
      }
    }
    if (smallerDimension < 768) {
      return {
        baseIconSize: Math.max(48, smallerDimension * 0.07),
        maxScale: 1.5,
        effectWidth: smallerDimension * 0.35,
      }
    }
    if (smallerDimension < 1024) {
      return {
        baseIconSize: Math.max(56, smallerDimension * 0.06),
        maxScale: 1.6,
        effectWidth: smallerDimension * 0.3,
      }
    }
    return {
      baseIconSize: Math.max(64, Math.min(80, smallerDimension * 0.05)),
      maxScale: 1.8,
      effectWidth: 300,
    }
  }, [])

  // Start from the SSR default on BOTH server and client (hydration-safe); the
  // mount effect below swaps in the real viewport size after hydration.
  const [config, setConfig] = useState(SSR_DEFAULT_CONFIG)
  const { baseIconSize, maxScale, effectWidth } = config
  const minScale = 1.0
  const baseSpacing = Math.max(4, baseIconSize * 0.08)

  useEffect(() => {
    const handleResize = () => {
      setConfig(getResponsiveConfig())
    }

    handleResize() // adopt the real viewport once, after hydration
    window.addEventListener("resize", handleResize)
    return () => window.removeEventListener("resize", handleResize)
  }, [getResponsiveConfig])

  const calculateTargetMagnification = useCallback(
    (mousePosition: number | null) => {
      if (mousePosition === null) {
        return apps.map(() => minScale)
      }

      return apps.map((_, index) => {
        const normalIconCenter = index * (baseIconSize + baseSpacing) + baseIconSize / 2
        const minX = mousePosition - effectWidth / 2
        const maxX = mousePosition + effectWidth / 2

        if (normalIconCenter < minX || normalIconCenter > maxX) {
          return minScale
        }

        const theta = ((normalIconCenter - minX) / effectWidth) * 2 * Math.PI
        const cappedTheta = Math.min(Math.max(theta, 0), 2 * Math.PI)
        const scaleFactor = (1 - Math.cos(cappedTheta)) / 2

        return minScale + scaleFactor * (maxScale - minScale)
      })
    },
    [apps, baseIconSize, baseSpacing, effectWidth, maxScale, minScale],
  )

  const calculatePositions = useCallback(
    (scales: number[]) => {
      let currentX = 0

      return scales.map(scale => {
        const scaledWidth = baseIconSize * scale
        const centerX = currentX + scaledWidth / 2
        currentX += scaledWidth + baseSpacing
        return centerX
      })
    },
    [baseIconSize, baseSpacing],
  )

  // Reset to resting scales whenever their inputs change, during render (React's "adjusting state
  // when a prop changes") rather than in an effect.
  const resetInputs = [apps, calculatePositions, minScale, config] as const
  const [resetFor, setResetFor] = useState<readonly unknown[]>([])
  if (resetInputs.some((input, i) => input !== resetFor[i])) {
    const initialScales = apps.map(() => minScale)
    setResetFor(resetInputs)
    setCurrentScales(initialScales)
    setCurrentPositions(calculatePositions(initialScales))
  }

  /* eslint-disable react-hooks/immutability -- rAF lerp reads/writes the same scale/position state each frame by design */
  const animateToTarget = useCallback(() => {
    const targetScales = calculateTargetMagnification(mouseX)
    const targetPositions = calculatePositions(targetScales)
    const lerpFactor = mouseX !== null ? 0.2 : 0.12

    setCurrentScales(prevScales => {
      return prevScales.map((currentScale, index) => {
        const diff = targetScales[index] - currentScale
        return currentScale + diff * lerpFactor
      })
    })

    setCurrentPositions(prevPositions => {
      return prevPositions.map((currentPos, index) => {
        const diff = targetPositions[index] - currentPos
        return currentPos + diff * lerpFactor
      })
    })

    const scalesNeedUpdate = currentScales.some(
      (scale, index) => Math.abs(scale - targetScales[index]) > 0.002,
    )
    const positionsNeedUpdate = currentPositions.some(
      (pos, index) => Math.abs(pos - targetPositions[index]) > 0.1,
    )

    if (scalesNeedUpdate || positionsNeedUpdate || mouseX !== null) {
      animationFrameRef.current = requestAnimationFrame(animateToTarget)
    }
  }, [mouseX, calculateTargetMagnification, calculatePositions, currentScales, currentPositions])
  /* eslint-enable react-hooks/immutability */

  useEffect(() => {
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current)
    }
    animationFrameRef.current = requestAnimationFrame(animateToTarget)

    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current)
      }
    }
  }, [animateToTarget])

  const handleMouseMove = useCallback(
    (e: React.MouseEvent) => {
      const now = performance.now()

      if (now - lastMouseMoveTime.current < 16) {
        return
      }

      lastMouseMoveTime.current = now

      if (dockRef.current) {
        const rect = dockRef.current.getBoundingClientRect()
        const padding = Math.max(8, baseIconSize * 0.12)
        setMouseX(e.clientX - rect.left - padding)
      }
    },
    [baseIconSize],
  )

  const handleMouseLeave = useCallback(() => {
    setMouseX(null)
  }, [])

  const handleAppClick = (appId: string, index: number) => {
    // No bounce — the DockTile popover opens instantly, so a bounce on some
    // icons (and not others) reads inconsistent. Just report the click + rect.
    onAppClick(appId, iconRefs.current[index]?.getBoundingClientRect() ?? null)
  }

  const contentWidth =
    currentPositions.length > 0
      ? Math.max(
          ...currentPositions.map(
            (pos, index) => pos + (baseIconSize * (currentScales[index] ?? minScale)) / 2,
          ),
        )
      : apps.length * baseIconSize + (apps.length - 1) * baseSpacing

  const padding = Math.max(8, baseIconSize * 0.12)

  return (
    <div
      className={cn(dockGlass, "[--dock-lift:0.2] dark:[--dock-lift:0.4]", className)}
      onMouseLeave={handleMouseLeave}
      onMouseMove={handleMouseMove}
      ref={dockRef}
      role="button"
      tabIndex={0}
      style={{
        width: `${contentWidth + padding * 2}px`,
        borderRadius: `${Math.max(12, baseIconSize * 0.4)}px`,
        padding: `${padding}px`,
      }}
    >
      <div
        className="relative"
        style={{
          height: `${baseIconSize}px`,
          width: "100%",
        }}
      >
        {apps.map((app, index) => {
          const scale = currentScales[index]
          const position = currentPositions[index] || 0

          // The item's own scale enlarges the shadow with the icon; only its depth grows here.
          const iconShadow = `drop-shadow(0 ${Math.max(1, baseIconSize * 0.03)}px ${Math.max(2, baseIconSize * 0.06)}px rgba(0,0,0,calc(var(--dock-lift) + ${(scale - 1) * 0.15})))`
          const itemClass = "group absolute cursor-pointer flex flex-col items-center justify-end"
          const itemStyle: React.CSSProperties = {
            // Magnification is transform-only (compositor), never left/width/height, which
            // re-ran layout for every icon on every frame. getBoundingClientRect includes it.
            left: 0,
            bottom: "0px",
            width: `${baseIconSize}px`,
            height: `${baseIconSize}px`,
            transform: `translateX(${position - baseIconSize / 2}px) scale(${scale})`,
            transformOrigin: "bottom center",
            zIndex: Math.round(scale * 10),
          }
          const setRef = (el: HTMLElement | null) => {
            iconRefs.current[index] = el
          }

          const body = (
            <>
              {app.content ? (
                <div className="relative h-full w-full" style={{ filter: iconShadow }}>
                  {/* Pressed: darkens on mouse-down and back on release, instantly, as
                      the macOS Dock does — feedback on the press, not on the click. */}
                  <div className="h-full w-full group-active:brightness-[0.72]">{app.content}</div>
                </div>
              ) : (
                // eslint-disable-next-line @next/next/no-img-element -- generic URL-icon fallback; DockTile passes `content` nodes
                <img
                  alt={app.name}
                  className="object-contain"
                  height={baseIconSize}
                  src={app.icon}
                  style={{ filter: iconShadow }}
                  width={baseIconSize}
                />
              )}

              {/* Native-style hover tooltip. Sits in the Dock's own stacking
                  context (backdrop-filter), so it always renders BEHIND the
                  DockTile popover (which is a higher-z sibling of the Dock).
                  Instant, as the macOS Dock's labels are: sweeping the Dock shows dozens.
                  Counter-scaled so the magnified item doesn't enlarge it. */}
              <span
                aria-hidden
                className={`pointer-events-none absolute bottom-full left-1/2 z-50 origin-bottom -translate-x-1/2 whitespace-nowrap opacity-0 group-hover:opacity-100 ${dockTooltip}`}
                style={{ scale: `${1 / scale}`, marginBottom: `${8 / scale}px` }}
              >
                {app.name}
              </span>

              {/* The open dot under the tile, dark on light glass and light on dark, as macOS
                  draws it. Counter-scaled about its top edge so magnification doesn't grow it. */}
              {openApps.includes(app.id) && (
                <div
                  className={`absolute left-1/2 -translate-x-1/2 rounded-full ${dockDot}`}
                  style={{
                    top: `calc(100% - ${Math.max(3, baseIconSize * 0.06) / 2 / scale}px)`,
                    width: `${Math.max(3, baseIconSize * 0.06)}px`,
                    height: `${Math.max(3, baseIconSize * 0.06)}px`,
                    scale: `${1 / scale}`,
                    transformOrigin: "50% 0",
                  }}
                />
              )}
            </>
          )

          return (
            <div
              className={itemClass}
              key={app.id}
              onClick={() => handleAppClick(app.id, index)}
              onKeyDown={e => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault()
                  handleAppClick(app.id, index)
                }
              }}
              data-app-id={app.id}
              ref={setRef}
              role="button"
              tabIndex={0}
              style={itemStyle}
              aria-label={app.name}
            >
              {body}
            </div>
          )
        })}
      </div>
    </div>
  )
}

export { MacOSDock, type DockApp, type MacOSDockProps }

