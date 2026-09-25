pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Singleton {
    id: root

    property int quipIndex: 0
    property var currentQuip: computeQuip()

    Connections {
        target: Weather
        function onDataChanged() {
            root.currentQuip = root.computeQuip()
        }
        function onEnabledChanged() {
            root.currentQuip = root.computeQuip()
        }
    }

    Connections {
        target: Translation
        function onTranslationsChanged() {
            root.currentQuip = root.computeQuip()
        }
    }

    Connections {
        target: DateTime
        function onTimeChanged() {
            // Periodically re-evaluate every 15 minutes
            if (DateTime.minute % 15 === 0) {
                root.currentQuip = root.computeQuip()
            }
        }
    }

    function shuffle() {
        quipIndex++
        currentQuip = computeQuip()
    }

    function computeQuip() {
        const pool = getQuipPool()
        if (!pool || pool.length === 0) {
            return {
                text: "• " + Translation.tr("Pleasant day, enjoy your work"),
                icon: "favorite"
            }
        }
        const idx = Math.abs(quipIndex) % pool.length
        const item = pool[idx]
        return {
            text: "• " + Translation.tr(item.key),
            icon: item.icon
        }
    }

    function getQuipPool() {
        const hour = DateTime.hour24

        // 1. When weather service is disabled -> general context quotes
        if (!Weather.enabled) {
            if (hour >= 23 || hour < 5) {
                return [
                    { key: "Late night, time to rest", icon: "bedtime" },
                    { key: "Sweet dreams and good night", icon: "nightlight" }
                ]
            }
            if (hour < 9) {
                return [
                    { key: "Good morning! Seize the day", icon: "wb_sunny" },
                    { key: "Start fresh with good energy", icon: "local_cafe" }
                ]
            }
            return [
                { key: "Stay focused, keep building", icon: "code" },
                { key: "Small daily steps count", icon: "school" },
                { key: "Enjoy every creative moment", icon: "favorite" }
            ]
        }

        const desc = (Weather.data?.description ?? "").toLowerCase()
        const tempNum = parseInt(Weather.data?.temp) || 25
        const feelsNum = parseInt(Weather.data?.tempFeelsLike) || tempNum
        const isNight = hour < 6 || hour >= 19

        // 2. Extreme Temperature Check
        if (feelsNum >= 36) {
            return [
                { key: "Scorching hot, stay hydrated", icon: "local_drink" },
                { key: "Peak heat, stay in the shade", icon: "thermostat" },
                { key: "Stay cool and hydrated", icon: "water_drop" }
            ]
        }

        if (tempNum <= 15 && tempNum > 0) {
            return [
                { key: "Chilly outside, keep warm", icon: "ac_unit" },
                { key: "Crisp air, sip warm tea", icon: "coffee" },
                { key: "Cool day, bundle up outside", icon: "dry_cleaning" }
            ]
        }

        // 3. Thunderstorm / Storm
        if (desc.includes("thunder") || desc.includes("storm") || desc.includes("lightning")) {
            return [
                { key: "Stormy outside, stay cozy indoors", icon: "bolt" },
                { key: "Heavy rain, take care on roads", icon: "shield" },
                { key: "Thunder outside, smooth code inside", icon: "code" }
            ]
        }

        // 4. Rain / Drizzle / Shower
        if (desc.includes("rain") || desc.includes("drizzle") || desc.includes("shower")) {
            if (desc.includes("light") || desc.includes("patchy")) {
                return [
                    { key: "Raining, grab a warm coffee", icon: "coffee" },
                    { key: "Passing shower, keep an umbrella", icon: "umbrella" },
                    { key: "Gentle rain, peaceful focus", icon: "water_drop" },
                    { key: "Light rain cooling the air", icon: "water" }
                ]
            }

            return [
                { key: "Rainy day, warm coffee time", icon: "coffee" },
                { key: "Rainy vibes, calm and focused", icon: "umbrella" },
                { key: "Rainy rhythm, get things done", icon: "code" }
            ]
        }

        // 5. Mist / Fog / Haze
        if (desc.includes("mist") || desc.includes("fog") || desc.includes("haze")) {
            return [
                { key: "Misty air, city slows down", icon: "foggy" },
                { key: "Foggy vibes, chill music time", icon: "headphones" },
                { key: "Misty roads, drive safe", icon: "visibility" }
            ]
        }

        // 6. Clear / Sunny
        if (desc.includes("clear") || desc.includes("sun")) {
            if (isNight) {
                return [
                    { key: "Starlit night, time to unwind", icon: "nightlight" },
                    { key: "Peaceful night, recharge well", icon: "bedtime" },
                    { key: "Clear sky, have a good sleep", icon: "star" }
                ]
            }

            if (hour < 10) {
                return [
                    { key: "Morning sunshine, stay inspired", icon: "wb_twilight" },
                    { key: "Morning glow, soak in the energy", icon: "flare" }
                ]
            }

            if (hour >= 17) {
                return [
                    { key: "Golden sunset, let go of worries", icon: "wb_twilight" },
                    { key: "Evening glow, enjoy your night", icon: "nightlight" }
                ]
            }

            return [
                { key: "Sunny day, touch some grass", icon: "nature_people" },
                { key: "Warm sunshine, time to shine", icon: "wb_sunny" },
                { key: "Great day to do what you love", icon: "flare" }
            ]
        }

        // 7. Clouds / Overcast / Broken / Scattered
        if (desc.includes("cloud")) {
            if (desc.includes("few") || desc.includes("scattered") || desc.includes("partly")) {
                return [
                    { key: "Scattered clouds, gentle breeze", icon: "cloud" },
                    { key: "Sun through clouds, easy breezy", icon: "air" },
                    { key: "Mild weather, great energy", icon: "filter_drama" }
                ]
            }

            return [
                { key: "Drifting clouds, peaceful mind", icon: "cloud" },
                { key: "Overcast sky, deep focus", icon: "filter_drama" },
                { key: "Shady clouds, another calm day", icon: "cloud_queue" }
            ]
        }

        // 8. Snow
        if (desc.includes("snow")) {
            return [
                { key: "Romantic snowfall, keep warm", icon: "ac_unit" },
                { key: "Winter chill, stay cozy indoors", icon: "severe_cold" }
            ]
        }

        // Fallback
        return [
            { key: "Pleasant day, enjoy your work", icon: "favorite" }
        ]
    }
}
