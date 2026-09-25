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
                text: "• " + Translation.tr("Pleasant weather, have a wonderful and productive day"),
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
                    { key: "It's late at night, get some rest", icon: "bedtime" },
                    { key: "Sweet dreams and peaceful rest", icon: "nightlight" }
                ]
            }
            if (hour < 9) {
                return [
                    { key: "Good morning! Ready to seize the day", icon: "wb_sunny" },
                    { key: "Start the day with focus and positive energy", icon: "local_cafe" }
                ]
            }
            return [
                { key: "Stay focused and keep building", icon: "code" },
                { key: "Small progress every day adds up", icon: "school" },
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
                { key: "Scorching hot outside, stay well hydrated", icon: "local_drink" },
                { key: "Peak heat today, stay in the cool shade", icon: "thermostat" },
                { key: "Keep your space cool and drink enough electrolytes", icon: "water_drop" }
            ]
        }

        if (tempNum <= 15 && tempNum > 0) {
            return [
                { key: "Chilly breeze outside, keep yourself warm", icon: "ac_unit" },
                { key: "Cool crisp air, perfect for a cup of warm tea", icon: "coffee" },
                { key: "Cool weather today, bundle up before going out", icon: "dry_cleaning" }
            ]
        }

        // 3. Thunderstorm / Storm
        if (desc.includes("thunder") || desc.includes("storm") || desc.includes("lightning")) {
            return [
                { key: "Stormy weather outside, stay safe and cozy indoors", icon: "bolt" },
                { key: "Heavy rain and wind, roads are slippery so take care", icon: "shield" },
                { key: "Roaring thunder outside, smooth code without bugs", icon: "code" }
            ]
        }

        // 4. Rain / Drizzle / Shower
        if (desc.includes("rain") || desc.includes("drizzle") || desc.includes("shower")) {
            if (desc.includes("light") || desc.includes("patchy")) {
                return [
                    { key: "Raining outside, perfect time for a warm coffee", icon: "coffee" },
                    { key: "Passing sun shower, keep an umbrella handy", icon: "umbrella" },
                    { key: "Gentle raindrops outside, a peaceful corner to focus", icon: "water_drop" },
                    { key: "A light rain cooling down the midday heat", icon: "water" }
                ]
            }

            return [
                { key: "Raining outside, grab a cup of hot coffee", icon: "coffee" },
                { key: "Rainy day vibes, calm mind and deep focus", icon: "umbrella" },
                { key: "Sound of raindrops, time to get things done", icon: "code" }
            ]
        }

        // 5. Mist / Fog / Haze
        if (desc.includes("mist") || desc.includes("fog") || desc.includes("haze")) {
            return [
                { key: "Misty atmosphere, the city slows down a beat", icon: "foggy" },
                { key: "Foggy vibes outside, great time for chill music", icon: "headphones" },
                { key: "Misty streets outside, drive safe and turn on fog lights", icon: "visibility" }
            ]
        }

        // 6. Clear / Sunny
        if (desc.includes("clear") || desc.includes("sun")) {
            if (isNight) {
                return [
                    { key: "Clear starlit night, quiet time to unwind", icon: "nightlight" },
                    { key: "Peaceful night sky, rest well and recharge", icon: "bedtime" },
                    { key: "Clear sky tonight, wishing you a good sleep", icon: "star" }
                ]
            }

            if (hour < 10) {
                return [
                    { key: "Crisp morning sunshine, ready for an inspiring day", icon: "wb_twilight" },
                    { key: "Morning glow is up, soak in the positive energy", icon: "flare" }
                ]
            }

            if (hour >= 17) {
                return [
                    { key: "Beautiful golden sunset, let go of daily worries", icon: "wb_twilight" },
                    { key: "Evening glow settling in, enjoy your relaxing night", icon: "nightlight" }
                ]
            }

            return [
                { key: "Bright sunny day, perfect time to touch grass", icon: "nature_people" },
                { key: "Warm sunshine all around, great moment to break through", icon: "wb_sunny" },
                { key: "A wonderful day to pursue what you love", icon: "flare" }
            ]
        }

        // 7. Clouds / Overcast / Broken / Scattered
        if (desc.includes("cloud")) {
            if (desc.includes("few") || desc.includes("scattered") || desc.includes("partly")) {
                return [
                    { key: "Pleasant scattered clouds, gentle breeze all around", icon: "cloud" },
                    { key: "Gentle sun through the clouds, relaxed and breezy", icon: "air" },
                    { key: "Ideal mild weather, plenty of energy for good work", icon: "filter_drama" }
                ]
            }

            return [
                { key: "Clouds drifting by, peace and lightness in mind", icon: "cloud" },
                { key: "Serene overcast sky, perfect atmosphere for deep focus", icon: "filter_drama" },
                { key: "Shady cool clouds, another peaceful day unfolds", icon: "cloud_queue" }
            ]
        }

        // 8. Snow
        if (desc.includes("snow")) {
            return [
                { key: "Romantic snowfall, keep warm with a hot drink", icon: "ac_unit" },
                { key: "Winter wonderland, enjoy the coziness indoors", icon: "severe_cold" }
            ]
        }

        // Fallback
        return [
            { key: "Pleasant weather, have a wonderful and productive day", icon: "favorite" }
        ]
    }
}
