#!/usr/bin/env -S -- node

import { Readability } from "@mozilla/readability";
import { JSDOM } from "jsdom";
import { exit, stdin, stdout } from "node:process";
import { text } from "node:stream/consumers";
import { pipeline } from "node:stream/promises";

const read = await text(stdin);
const {
  window: { document },
} = new JSDOM(read);
const { textContent } = new Readability(document).parse() ?? {};

if (!textContent) {
  exit(1);
} else {
  await pipeline(textContent, stdout);
}
