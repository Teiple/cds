package game

import sapp "sokol/app"

Scene_State :: union {
   Scene_State_Title,
   Scene_State_Main_Menu,
   Scene_State_Gameplay,
}

Scene_Callbacks :: struct {
   init            : proc(),
   destroy         : proc(),
   update          : proc(dt: f32),
   draw_3d         : proc(),
   draw_ui         : proc(),
   handle_input_3d : proc(ev: sapp.Event),
   handle_input_ui : proc(ev: sapp.Event)
}

scene_set :: proc(state: Scene_State) {
   assert(state != nil)

	if g_state.scene.callbacks.destroy != nil {
		g_state.scene.callbacks.destroy()
	}
	
   g_state.scene.state     = state
	g_state.scene.callbacks = scene_get_callbacks(state)

	if g_state.scene.callbacks.init != nil {
		g_state.scene.callbacks.init()
	}
}

scene_get_callbacks :: proc(scene_state : Scene_State) -> Scene_Callbacks {
   switch state in scene_state {
   case Scene_State_Title:
      return SCENE_CALLBACKS_TITLE
   case Scene_State_Main_Menu:
      return SCENE_CALLBACKS_MAIN_MENU
   case Scene_State_Gameplay:
      return SCENE_CALLBACKS_GAMEPLAY
   }
   panic("Scene state should not be nil right now")
}