local _, ns = ...

ns.RegisterModule({
    key = "Letterbox",
    category = "Effects",
    title = "Letterbox",
    description = "Cinematic black bars at the top and bottom of the screen.",
    lens = true,
    enabledByDefault = true,
    combinedByDefault = true,
    settings = {
        {
            key = "height",
            type = "slider",
            title = "Bar height",
            description = "Height of each bar, in percent of the screen height.",
            min = 1,
            max = 25,
            step = 0.5,
            default = 10,
            format = "%.1f%%",
        },
        {
            key = "duration",
            type = "slider",
            title = "Animation duration",
            description = "How long the bars take to slide in and out, in seconds. At 0 they appear and disappear at once.",
            min = 0,
            max = 3,
            step = 0.1,
            default = 0.5,
            format = "%.1f s",
        },
    },
})
