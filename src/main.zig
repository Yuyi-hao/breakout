const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

// constant 
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;

// game constant 
const FPS: comptime_int = 60;
const STRIKER_SIZE = 20;
const RECT_SPEED:f32 = 500;
const DELTA_TIME_SEC: f32 = 1.0/@intToFloat(f32, FPS);
const BAR_LENGTH = 100;
const BAR_THICKNESS = STRIKER_SIZE;
const BAR_Y = WINDOW_HEIGHT - BAR_THICKNESS - 50;
const BAR_SPEED:f32 = 2*RECT_SPEED;
const TARGET_LENGTH = BAR_LENGTH;
const TARGET_HEIGH = BAR_THICKNESS;
const TARGET_PADDING = 50;
const TARGET_CAPACITY = 128;

const Target = struct {
    x: f32,
    y: f32,
    dead: bool = false,
};

var target_pool = [_]Target{
    Target{ .x = 100, .y = 200},
    Target{ .x = 100 + TARGET_LENGTH + TARGET_PADDING, .y = 200},
    Target{ .x = 100 + 2*(TARGET_LENGTH + TARGET_PADDING), .y = 200},
    Target{ .x = 100 + 3*(TARGET_LENGTH + TARGET_PADDING), .y = 200},
    Target{ .x = 100, .y = 240},
    Target{ .x = 100 + TARGET_LENGTH + TARGET_PADDING, .y = 240},
    Target{ .x = 100 + 2*(TARGET_LENGTH + TARGET_PADDING), .y = 240},
    Target{ .x = 100 + 3*(TARGET_LENGTH + TARGET_PADDING), .y = 240},
    Target{ .x = 100, .y = 280},
    Target{ .x = 100 + TARGET_LENGTH + TARGET_PADDING, .y = 280},
    Target{ .x = 100 + 2*(TARGET_LENGTH + TARGET_PADDING), .y = 280},
    Target{ .x = 100 + 3*(TARGET_LENGTH + TARGET_PADDING), .y = 280},
    Target{ .x = 100, .y = 320},
    Target{ .x = 100 + TARGET_LENGTH + TARGET_PADDING, .y = 320},
    Target{ .x = 100 + 2*(TARGET_LENGTH + TARGET_PADDING), .y = 320},
    Target{ .x = 100 + 3*(TARGET_LENGTH + TARGET_PADDING), .y = 320},
};

var target_pool_cnt:usize = 1;

// game variable 
var bar_x:f32 = WINDOW_WIDTH/2 - BAR_LENGTH/2;
var striker_x:f32 = WINDOW_WIDTH/2 - STRIKER_SIZE/2;
var striker_y:f32 = BAR_Y - BAR_THICKNESS/2 - STRIKER_SIZE;
var striker_dx:f32 = 1;
var striker_dy:f32 = 1;
var bar_dx:f32 = 1;
var pause = false;
var started = false;
var score: i32 = 0;


fn striker_rect(x: f32, y: f32) c.SDL_Rect{
    const striker_rectangle = c.SDL_Rect{
        .x = @floatToInt(i32, x),
        .y = @floatToInt(i32, y),
        .w = STRIKER_SIZE,
        .h = STRIKER_SIZE,
    };
    return striker_rectangle;
}

fn target_rect(target: Target) c.SDL_Rect{
    const target_rectangle = c.SDL_Rect{
        .x = @floatToInt(i32, target.x),
        .y = @floatToInt(i32, target.y),
        .w = TARGET_LENGTH,
        .h = TARGET_HEIGH,
    };
    return target_rectangle;
}

fn bar_rect() c.SDL_Rect{
    const bar_rectangle = c.SDL_Rect{
        .x = @floatToInt(i32, bar_x),
        .y = BAR_Y - BAR_THICKNESS/2,
        .w = BAR_LENGTH,
        .h = BAR_THICKNESS,
    };
    return bar_rectangle;
}

fn update(dt: f32) anyerror!void{ 
    if(!pause and started){
        bar_x = math.clamp(bar_x + bar_dx*BAR_SPEED*dt, 0, WINDOW_WIDTH - BAR_LENGTH);
        var striker_new_x = striker_x + striker_dx*RECT_SPEED*dt;
        var cond_x = (striker_new_x < 0) or (striker_new_x + @intToFloat(f32, STRIKER_SIZE)> WINDOW_WIDTH or c.SDL_HasIntersection(&striker_rect(striker_new_x, striker_y), &bar_rect()) != c.SDL_bool.SDL_FALSE);

        for (target_pool) |*target|{
            if(!target.dead){
                if(cond_x) break;
                cond_x = cond_x or c.SDL_HasIntersection(&striker_rect(striker_new_x, striker_y), &target_rect(target.*)) != c.SDL_bool.SDL_FALSE;
                if(cond_x){
                    (target.*).dead = true;
                    score += 1;
                }
            }
        }
        if(cond_x){
            striker_dx *= -1;
            striker_new_x = striker_x + striker_dx*RECT_SPEED*dt;
        }
        striker_x = striker_new_x;

        var striker_new_y = striker_y + striker_dy*RECT_SPEED*dt;
        var cond_y = (striker_new_y < 0) or (striker_new_y + @intToFloat(f32, STRIKER_SIZE)> WINDOW_HEIGHT) or c.SDL_HasIntersection(&striker_rect(striker_x, striker_new_y), &bar_rect()) != c.SDL_bool.SDL_FALSE;
        for (target_pool) |*target|{
            if(!target.dead){
                if(cond_y) break;
                cond_y = cond_y or c.SDL_HasIntersection(&striker_rect(striker_x, striker_new_y), &target_rect(target.*)) != c.SDL_bool.SDL_FALSE;
                if(cond_y){
                    (target.*).dead = true;
                    score += 1;
                }
            }
        }
        if(cond_y){
            striker_dy *= -1;
            striker_new_y = striker_y + striker_dy*RECT_SPEED*dt;
        }
        striker_y = striker_new_y;
    }


}


fn render(renderer: *c.SDL_Renderer) anyerror!void{
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
   
    _ = c.SDL_RenderFillRect(renderer, &striker_rect(striker_x, striker_y));


    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255);
    
    _ = c.SDL_RenderFillRect(renderer, &bar_rect());
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255);
    for(target_pool) |target| {
        if(!target.dead){
            _ = c.SDL_RenderFillRect(renderer, &target_rect(target));
        }
    }
}

pub fn main() anyerror!void {
    // Initialize SDL 
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    defer c.SDL_Quit();

    // Make a window 
    const window = c.SDL_CreateWindow("BreakOut", (1920 - WINDOW_WIDTH)/2, (1080 - WINDOW_HEIGHT)/2, WINDOW_WIDTH, WINDOW_HEIGHT, 0)
    orelse{
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    // Make a renderer 
    const renderer = c.SDL_CreateRenderer(window, -1, 0)
    orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    // event loop 
    var quit = false;
    while(!quit){
        var event: c.SDL_Event = undefined; // events 
        while (c.SDL_PollEvent(&event) != 0) { 
            switch (event.@"type") { 
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN =>{
                    switch(event.key.keysym.sym){
                        'q'  => {quit = true;},
                        ' '  => {pause = !pause;},
                        'p'  => {pause = true;},
                        'r'  => {pause = false;},
                        else => {}
                    }

                },
                else => {},
            }
        }
        _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
        _ = c.SDL_RenderClear(renderer);
        const keyboard = c.SDL_GetKeyboardState(null);

        bar_dx = 0;
        if(keyboard[c.SDL_SCANCODE_LEFT] != 0){
            bar_dx = -1;
            started = true;
        }
        if(keyboard[c.SDL_SCANCODE_RIGHT] != 0){
            bar_dx += 1;
            started = true;
        }


        try update(DELTA_TIME_SEC);

        try render(renderer);


        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(1000/FPS);
    } 


    std.log.debug("OK.", .{});
}

