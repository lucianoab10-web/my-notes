import { slugifyFilePath } from "@quartz-community/utils"
import { createResolver, loadMap, rewriteTree } from "../mineralogy-common/index.js"

export const manifest = {
  name: "mineralogy-links", displayName: "Mineralogy Wiki links", version: "1.0.0",
  category: "transformer", defaultOrder: 55,
}

export default function MineralogyLinks(options = {}) {
  return {
    name: "MineralogyLinks",
    htmlPlugins(ctx) {
      const resolve = createResolver(loadMap(options.mapPath), slugifyFilePath, options)
      return [() => (tree, file) => rewriteTree(tree, resolve, file.data.slug ?? "", ctx.allSlugs ?? [])]
    },
  }
}
