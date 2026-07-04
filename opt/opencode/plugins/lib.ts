export const parseFrontMatter = (text: string): string | undefined => {
  if (!text.startsWith("---")) {
    return undefined
  }

  return ""
}
