package game

import "core:fmt"
import sapp "sokol/app"
import ui "ui"
import uie "ui_extra"

Scene_State_Gameplay :: struct {
   is_paused   : bool,
   camera      : Camera,
   freecam     : Free_Camera,
   player      : Player,
   physics     : Physics,
	follow_cam  : Follow_Camera,
	environment : Environment,
}

SCENE_CALLBACKS_GAMEPLAY : Scene_Callbacks : {
   init = proc() {
      s := scene_state(Scene_State_Gameplay)

      physics_init(&s.physics)
      freecam_init(&s.freecam)
      follow_camera_init(&s.follow_cam, offset = {0, 0.2, 3.5})

      s.camera = {
         fovy_degrees = 60,
         position     = {0, 1.0, 3.5},
         target       = {0, 1.0, 0},
         up           = {0, 1, 0},
      }

      environment_init(&s.environment, s.physics.world)
      player_init(&s.player, s.physics.world, {0, 1.5, 0})
      mouse_set_locked(&g_state.mouse, true)
   },
   destroy = proc() {
      s := scene_state(Scene_State_Gameplay)

      player_destroy(&s.player)
      environment_destroy(&s.environment)
      physics_destroy(&s.physics)
   },
   update  = proc(dt : f32) {
      s := scene_state(Scene_State_Gameplay)
      
      physics_update(&s.physics, dt)

      if s.freecam.enabled {
         freecam_update(&s.freecam, &s.camera, dt)
      } else {
         player_update(&s.player, &s.camera, &g_state.viewport, &g_state.audio, dt)
         follow_camera_update(&s.follow_cam, &s.camera, player_get_position(&s.player), dt)
      }
   },
   draw_3d = proc() {
      s := scene_state(Scene_State_Gameplay)

      player_draw(&s.player, &s.camera, &g_state.viewport)

      debug_draw_grid(slices = 20, spacing = 1.0, color = {50, 50, 50, 255})
      physics_debug_render(&s.physics)
      debug_render(&g_state.debug_drawer, &s.camera, &g_state.viewport)
   },
   draw_ui = proc() {
      s := scene_state(Scene_State_Gameplay)

      // Pause menu
      if s.is_paused {
         pause_menu()
      }
   },
   handle_input_ui = proc(ev : sapp.Event) {
      s := scene_state(Scene_State_Gameplay)
      freecam_reset_input(&s.freecam)
   },
   handle_input_3d = proc(ev : sapp.Event) {
      mouse_update_input_event(&g_state.mouse, &g_state.viewport, ev)
      s := scene_state(Scene_State_Gameplay)
      
      if s.freecam.enabled {
         freecam_update_input_event(&s.freecam, ev)
      }

      if ev.type == .KEY_UP && ev.key_code == .ESCAPE {
         s.is_paused = !s.is_paused
      }
   },
}

pause_menu :: proc() {
   // backdrops
   if ui.layout(
      width            = ui.grow(),
      height           = ui.grow(),
      background_color = uie.hsva_to_rgba({0, 0, 0, 0.25}),
      float_mode       = ui.Float_At_Root{},
   ) {}

   // options
   if ui.layout(
      layout_direction = .Top_To_Bottom,
      float_mode       = ui.Float_At_Root{
         attach_points = {
            element = .LeftCenter,
            parent  = .CenterCenter,
         }
      },
   ) {
      uie.label_button("Resume")
      uie.label_button("Restart")
      uie.label_button("Settings")
      uie.label_button("Main Menu")
      uie.label_button("Exit game")
   }
}