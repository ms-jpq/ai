#!/usr/bin/env -S -- node

import { buildClientSchema, getIntrospectionQuery, printSchema } from "graphql";
import { ok } from "node:assert";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { dirname, join } from "node:path";
import { argv, stdout } from "node:process";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { fileURLToPath } from "node:url";

const dir = dirname(fileURLToPath(import.meta.url));
const query = JSON.stringify({
  query: getIntrospectionQuery({
    directiveIsRepeatable: true,
    schemaDescription: true,
  }),
});

const f = (async function* () {
  const abortion = new AbortController();
  try {
    const proc = spawn(
      "curl",
      [
        "--config",
        join(dir, "curlrc"),
        "--data",
        "@-",
        "--header",
        "Content-Type: application/json",
        "--header",
        "Accept: application/json",
        "--no-progress-meter",
        ...argv.slice(2),
      ],
      {
        stdio: ["pipe", "pipe", "inherit"],
        signal: abortion.signal,
      },
    );
    const code = once(proc, "exit");
    const { stdin, stdout } = proc;
    const web = /** @type {ReadableStream<Uint8Array>} */ (
      /** @type {unknown} */ (Readable.toWeb(stdout))
    );
    const out = web.pipeThrough(new TextDecoderStream());
    const o = /** @type {AsyncIterableIterator<string>} */ (
      /** @type {unknown} */ (out)
    );
    const pipe = pipeline(query, stdin);
    try {
      await code;
      yield* o;
    } finally {
      await pipe;
      await code;
    }
    const [status, signal] = await code;
    ok(!status, JSON.stringify([status, signal], undefined, 2));
  } finally {
    abortion.abort();
  }
})();

/** @type {string[]} */
const acc = [];
for await (const c of f) {
  acc.push(c);
}
const { data, error } = JSON.parse(acc.join(""));
ok(!error, JSON.stringify(error, undefined, 2));

const schema = buildClientSchema(data);
const graphql = printSchema(schema);
await pipeline(graphql, stdout);
