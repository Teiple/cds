package game

import sapp "sokol/app"

Scene_State_Gameplay :: struct {
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

      freecam_init()
      follow_camera_init(offset = {0, 0.2, 3.5})
      physics_init()
      environment_init()

      s.camera = {
         fovy_degrees = 60,
         position     = {0, 1.0, 3.5},
         target       = {0, 1.0, 0},
         up           = {0, 1, 0},
      }

      player_init({0, 1.5, 0})
      mouse_set_locked(true)
   },
   destroy = proc() {
      s := scene_state(Scene_State_Gameplay)

      player_destroy()
      environment_destroy()
      physics_destroy()
   },
   update  = proc(dt : f32) {
      s := scene_state(Scene_State_Gameplay)
      
      physics_update(dt)

      if s.freecam.enabled {
         freecam_update(dt)
      } else {
         player_update(dt)
         follow_camera_update(dt)
      }
   },
   draw_3d = proc() {
      player_draw()

      debug_draw_grid(slices = 20, spacing = 1.0, color = {50, 50, 50, 255})
      physics_debug_render()
      debug_render(&g_state.debug_drawer)
   },
   draw_ui = proc() {

   },
   handle_input_ui = proc(ev : sapp.Event) {

   },
   handle_input_3d = proc(ev : sapp.Event) {
      mouse_update_input_event(ev)
      s := scene_state(Scene_State_Gameplay)
      if s.freecam.enabled {
         freecam_update_input_event(ev)
      }
   },
}