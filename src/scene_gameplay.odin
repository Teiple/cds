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

   },
   destroy = proc() {

   },
   update  = proc(dt : f32) {

   },
   draw_3d = proc() {

   },
   draw_ui = proc() {

   },
   handle_input_ui = proc(ev : sapp.Event) {

   },
   handle_input_3d = proc(ev : sapp.Event) {

   }
}