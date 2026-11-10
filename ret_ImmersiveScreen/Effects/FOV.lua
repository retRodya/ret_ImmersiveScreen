local _, ns = ...

ns.RegisterModule({
    key = "FOV",
    category = "Effects",
    title = "FOV",
    description = "Changes the camera's field of view, within the range the game allows.",
    placeholder = true,
    lens = true,
    settings = {
        {
            key = "fov",
            type = "slider",
            title = "Field of view",
            description = "The camera's field of view, in degrees.",
            min = 50,
            max = 90,
            step = 1,
            default = 90,
            format = "%d",
        },
    },
})
