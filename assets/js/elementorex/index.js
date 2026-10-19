// ElementorexCms — JavaScript of the editor and the public runtime.
//
//   import {hooks as Elementorex} from "elementorex_cms"
//   const liveSocket = new LiveSocket("/live", Socket, {hooks: {...Elementorex}})
//
// The package ships as plain ES modules inside the Hex package; esbuild finds it
// through the NODE_PATH that points to deps/ (Phoenix's default configuration).

import { ElementorexEditor } from "./editor_hook"
import { ElementorexRuntime, initElementorex, stopElementorex } from "./runtime"

export const hooks = { ElementorexEditor, ElementorexRuntime }

export { ElementorexEditor, ElementorexRuntime, initElementorex, stopElementorex }

export default hooks
