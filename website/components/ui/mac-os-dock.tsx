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
  /** A non-interactive separator, like the real Dock's — never magnified. */
  kind?: "divider"
  /** Render the item as a real link (crawlable, keyboard-native). */
  href?: string
  /** With `href`: open in a new tab and announce it via `externalHint`. */
  external?: boolean
  /** Replaces `name` in the hover tooltip (the accessible name stays `name`). */
  tooltip?: React.ReactNode
  /** Caption under the icon, shown only where there is no hover (touch). */
  label?: React.ReactNode
}

interface MacOSDockProps {
  apps: DockApp[]
  /** Receives the clicked app id plus the clicked icon's live bounding rect
   *  (for anchoring a popover to the icon). */
  onAppClick: (appId: string, rect: DOMRect | null) => void
  openApps?: string[]
  className?: string
  /** Appended to an external link item's accessible name, e.g. "(opens in a new tab)". */
  externalHint?: string
}

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
  externalHint,
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
  // Touch labels sit under the icons and are wider than them, so where there
  // is no hover a labelled Dock spaces its items for the text. Starts false on
  // both server and client (hydration-safe), like `config`.
  const hasLabels = apps.some(app => app.label)
  const [noHover, setNoHover] = useState(false)
  useEffect(() => {
    if (!hasLabels) return
    const query = window.matchMedia("(hover: none)")
    const sync = () => setNoHover(query.matches)
    sync()
    query.addEventListener("change", sync)
    return () => query.removeEventListener("change", sync)
  }, [hasLabels])
  const baseSpacing =
    hasLabels && noHover ? baseIconSize * 0.55 : Math.max(4, baseIconSize * 0.08)
  const dividerWidth = Math.max(8, baseIconSize * 0.2)
  // Width of item i at a given scale. Dividers never magnify. With no dividers
  // every layout formula below reduces to the original index-based one.
  const itemWidth = useCallback(
    (app: DockApp, scale: number) =>
      app.kind === "divider" ? dividerWidth : baseIconSize * scale,
    [baseIconSize, dividerWidth],
  )

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

      let restX = 0
      return apps.map(app => {
        const restWidth = itemWidth(app, minScale)
        const normalIconCenter = restX + restWidth / 2
        restX += restWidth + baseSpacing
        if (app.kind === "divider") return minScale
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
    [apps, itemWidth, baseSpacing, effectWidth, maxScale, minScale],
  )

  const calculatePositions = useCallback(
    (scales: number[]) => {
      let currentX = 0

      return scales.map((scale, index) => {
        const scaledWidth = itemWidth(apps[index], scale)
        const centerX = currentX + scaledWidth / 2
        currentX += scaledWidth + baseSpacing
        return centerX
      })
    },
    [apps, itemWidth, baseSpacing],
  )

  useEffect(() => {
    const initialScales = apps.map(() => minScale)
    const initialPositions = calculatePositions(initialScales)
    setCurrentScales(initialScales)
    setCurrentPositions(initialPositions)
  }, [apps, calculatePositions, minScale, config])

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
            (pos, index) => pos + itemWidth(apps[index], currentScales[index] ?? minScale) / 2,
          ),
        )
      : apps.reduce((sum, app) => sum + itemWidth(app, minScale), 0) +
        (apps.length - 1) * baseSpacing

  const padding = Math.max(8, baseIconSize * 0.12)
  // A Dock of real links must not itself be a button (nested interactive
  // elements are invalid ARIA); the hero's button-only Dock keeps its role.
  const hasLinks = apps.some(app => app.href)

  return (
    <div
      className={cn("backdrop-blur-md", className)}
      onMouseLeave={handleMouseLeave}
      onMouseMove={handleMouseMove}
      ref={dockRef}
      role={hasLinks ? undefined : "button"}
      tabIndex={hasLinks ? undefined : 0}
      style={{
        width: `${contentWidth + padding * 2}px`,
        background: "rgba(45, 45, 45, 0.75)",
        borderRadius: `${Math.max(12, baseIconSize * 0.4)}px`,
        border: "1px solid rgba(255, 255, 255, 0.15)",
        boxShadow: `
          0 ${Math.max(4, baseIconSize * 0.1)}px ${Math.max(16, baseIconSize * 0.4)}px rgba(0, 0, 0, 0.4),
          0 ${Math.max(2, baseIconSize * 0.05)}px ${Math.max(8, baseIconSize * 0.2)}px rgba(0, 0, 0, 0.3),
          inset 0 1px 0 rgba(255, 255, 255, 0.15),
          inset 0 -1px 0 rgba(0, 0, 0, 0.2)
        `,
        padding: `${padding}px`,
      }}
    >
      <div
        className={cn("relative", hasLabels && "[@media(hover:none)]:mb-4")}
        style={{
          height: `${baseIconSize}px`,
          width: "100%",
        }}
      >
        {apps.map((app, index) => {
          const scale = currentScales[index]
          const position = currentPositions[index] || 0
          const scaledSize = baseIconSize * scale

          if (app.kind === "divider") {
            return (
              <div
                aria-hidden
                className="absolute flex items-center justify-center"
                key={app.id}
                style={{
                  left: `${position - dividerWidth / 2}px`,
                  bottom: "0px",
                  width: `${dividerWidth}px`,
                  height: `${baseIconSize}px`,
                }}
              >
                <span className="h-[70%] w-px bg-white/25" />
              </div>
            )
          }

          const iconShadow = `drop-shadow(0 ${scale > 1.2 ? Math.max(2, baseIconSize * 0.05) : Math.max(1, baseIconSize * 0.03)}px ${scale > 1.2 ? Math.max(4, baseIconSize * 0.1) : Math.max(2, baseIconSize * 0.06)}px rgba(0,0,0,${0.2 + (scale - 1) * 0.15}))`
          const itemClass = "group absolute cursor-pointer flex flex-col items-center justify-end"
          const itemStyle: React.CSSProperties = {
            left: `${position - scaledSize / 2}px`,
            bottom: "0px",
            width: `${scaledSize}px`,
            height: `${scaledSize}px`,
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
                  height={scaledSize}
                  src={app.icon}
                  style={{ filter: iconShadow }}
                  width={scaledSize}
                />
              )}

              {/* Native-style hover tooltip. Sits in the Dock's own stacking
                  context (backdrop-filter), so it always renders BEHIND the
                  DockTile popover (which is a higher-z sibling of the Dock).
                  Items that carry a touch label hide it where there's no hover. */}
              <span
                aria-hidden
                className={cn(
                  "pointer-events-none absolute bottom-full left-1/2 z-50 mb-2 -translate-x-1/2 whitespace-nowrap rounded-md font-ui border border-white/10 bg-zinc-900/85 px-2 py-1 text-xs font-medium text-white opacity-0 shadow-md backdrop-blur-sm transition-opacity duration-150 group-hover:opacity-100 group-data-demo-hover:opacity-100",
                  app.label && "[@media(hover:none)]:hidden",
                )}
              >
                {app.tooltip ?? app.name}
              </span>

              {app.label && (
                <span
                  aria-hidden
                  className="pointer-events-none absolute top-full left-1/2 mt-1.5 hidden -translate-x-1/2 items-center whitespace-nowrap text-[11px] leading-none font-medium text-white/75 [@media(hover:none)]:flex"
                >
                  {app.label}
                </span>
              )}

              {openApps.includes(app.id) && (
                <div
                  className="absolute"
                  style={{
                    bottom: `${Math.max(-2, -baseIconSize * 0.05)}px`,
                    left: "50%",
                    transform: "translateX(-50%)",
                    width: `${Math.max(3, baseIconSize * 0.06)}px`,
                    height: `${Math.max(3, baseIconSize * 0.06)}px`,
                    borderRadius: "50%",
                    backgroundColor: "rgba(255, 255, 255, 0.8)",
                    boxShadow: "0 0 4px rgba(0, 0, 0, 0.3)",
                  }}
                />
              )}
            </>
          )

          // Link items are real anchors: native Enter activation (no keydown
          // handler — its preventDefault would kill the navigation), crawlable,
          // and an accessible name that announces a new tab.
          if (app.href) {
            return (
              <a
                className={itemClass}
                key={app.id}
                href={app.href}
                {...(app.external && { target: "_blank", rel: "noopener noreferrer" })}
                onClick={() => handleAppClick(app.id, index)}
                data-app-id={app.id}
                ref={setRef}
                style={itemStyle}
                aria-label={app.external && externalHint ? `${app.name} ${externalHint}` : app.name}
              >
                {body}
              </a>
            )
          }

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

