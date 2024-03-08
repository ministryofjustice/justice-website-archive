#!/usr/bin/env node
/**
 * Justice Archive - Node.js Processing
 * -
 *********************************************/
const express = require("express");
const path = require("path");
const app = express();
const port = 2000;
const cors = require("cors");
const { exec, execSync, spawn } = require("child_process");

app.use(express.urlencoded({ extended: true }));

app.use(
    cors({
        methods: ["POST"],
        origin: [
            "http://spider.justice.docker/",
            "https://justice-archiver.apps.live.cloud-platform.service.justice.gov.uk/",
        ],
    }),
);

app.post("/processing", async function (request, response, next) {
    // offload the request to a function that checks if httrack
    // has a running process, launch the spider if not
    let httrack_pid = await process_is_running("httrack");
    if (!httrack_pid) {
        response
            .status(200)
            .sendFile(path.join("/usr/share/nginx/html/working.html"));
        await spider(request.body);
    } else {
        let etime = execSync(
                "ps -p " + httrack_pid.toString().trim() + " -o etime=",
            )
                .toString()
                .trim()
                .split(":"),
            segments = ["second", "minute", "hour", "day"],
            elapsed_time = "",
            segment_count = etime.length;

        etime.reverse();

        for (let ii = 0; ii < segment_count; ii++) {
            let divider =
                ii + 1 === segment_count
                    ? " and "
                    : ii + 2 === segment_count
                    ? " "
                    : ", ";
            // 1 day, 3 hours, 8 minutes and 43 seconds
            if (etime[ii] !== "00") {
                elapsed_time =
                    parseInt(etime[ii]) +
                    " " +
                    segments[ii] +
                    (etime[ii] !== "01" ? "s" : "") +
                    divider +
                    elapsed_time;
            }
        }

        execSync(
            "sed -i -e 's/\\(<elapsed_time>\\).*\\(<\\/elapsed_time>\\)/<elapsed_time>" +
                elapsed_time +
                "<\\/elapsed_time>/g' /usr/share/nginx/html/rejected.html",
        );
        response
            .status(200)
            .sendFile(path.join("/usr/share/nginx/html/rejected.html"));
    }
});

/**
 * Spider justice.gov.uk, take a snapshot
 *
 * @param body form payload
 **/
async function spider(body) {
    await new Promise((resolve) => setTimeout(resolve, 1));
    const { spawn } = require("child_process");
    const mirror = {
        url: new URL("https://www.justice.gov.uk/"),
    };
    let directory = "/archiver/snapshots/" + mirror.url.host;

    // append date, like: 2023-01-17-18-00
    directory += "/" + new Date().toISOString().slice(0, 16).replace(/T|:/g, "-");

    // create our working directory
    mkdir(directory);

    // init httrack argument arrays
    let options, rules, settings;

    // define our core options
    options = [
        mirror.url.origin,
        "-%R", // set the referrer: https://www.mankier.com/1/httrack#-%25R
        mirror.url.origin,
        "-F", // set user agent to different string: https://www.mankier.com/1/httrack#-F
        '"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36"',
    ];

    /**
     * Define scraping rules
     * In the form of URL. Use wildcard astrix to shorten the capture
     *
     * + = follow
     * - = do not follow
     *
     * @type {string[]}
     */
    rules = [
        "+*.png",
        "+*.gif",
        "+*.jpg",
        "+*.jpeg",
        "+*.css",
        "+*.js",
        "+*.pdf",
        "+*.zip",
        "+*.doc",
        "+*.docx",
        "+*.xls",
        "+*.xlsx",
        "+*.svg",
        "+*.ico",
        "+*aka.justice.gov.uk/*",
        "-*ad.doubleclick.net/*",
        "-*widgets.twimg.com/*",
        "-*coveritlive.com/*",
        "-*www.justice.gov.uk/news-old/features?*",
        "-*/_admin*",
        "-*?a=*",
        "-*?SQ_BACKEND_PAGE=*",
    ];

    /**
     * Define scrape settings
     * A full list of settings are available: https://www.mankier.com/1/httrack
     *
     * @type {string[]}
     */
    settings = [
        "-s0", // never follow robots.txt and meta robots tags: https://www.mankier.com/1/httrack#-sN
        "-%k", // keep-alive if possible https://www.mankier.com/1/httrack#-%25k
        //'-I0', // don't make an index page https://www.mankier.com/1/httrack#-I
        //'-N100', // create without host directory https://www.mankier.com/1/httrack#-N100
        // sed was causing logs on binary files.
        // "-V", // execute system command after each file: https://www.mankier.com/1/httrack#-V
        // '"sed -i \'s/ id="popular-wrapper"//g\' $0"',
        "-O", // path for snapshot/logfiles+cache: https://www.mankier.com/1/httrack#-O
        directory,
        // absolute links means the result will not be browsable, but it's better for the migration process
        "-K", // absolute links : https://www.mankier.com/1/httrack#Options-Build_options
    ];

    // combine: push rules into options
    options = options.concat(rules);
    // combine: push settings into options
    options = options.concat(settings);
    // verify options array
    console.log("\n");
    console.log("Launching the MoJ Spider with the following options: ", options);
    console.log("\nStand by... \n");

    console.log("Starting data-sync process.");
    // empty s3sync.log
    execSync('echo "" > /archiver/s3sync.log');
    // start the sync process
    exec("s3sync-cron");

    // launch HTTrack with options
    const listener = spawn("httrack", options);
    listener.stdout.on("data", (data) => console.log(`httrack: ${data}`));
    listener.stderr.on("data", (data) => console.log(`httrack stderr: ${data}`));
    listener.on("error", (error) =>
        console.log(`httrack error: ${error.message}`),
    );
    listener.on("close", (code) => {
        console.log(
            `The MoJ Spider has completed the mirror process with exit code ${code}.`,
        );

        // stop the sync process
        execSync("kill -9 `cat /archiver/supercronic_sync.pid`");
        execSync("rm /archiver/supercronic_sync.pid");

        // generate an index page for the scrape
        create_index();
    });
}

function sync_all_data() {
    // launch s3sync
    console.log(
        "\nThe MoJ Spider is closing the session with a data-sync operation.",
    );
    const listener = spawn("s3sync");
    listener.stdout.on("data", (data) => null);
    listener.stderr.on("data", (data) => null);
    listener.on("error", (error) =>
        console.log(`s3sync error: ${error.message}`),
    );
    listener.on("close", (code) => {
        console.log("Synchronisation complete.\n");
    });

    // check if process still running after 5 minutes
    // kill if needed
    setTimeout(async () => {
        let s3sync_pid = await process_is_running("s3sync");
        if (s3sync_pid) {
            exec("kill -9 " + s3sync_pid.toString().trim());
        }
    }, 300000);
}

function create_index() {
    const listener = spawn("generate-index");
    listener.stdout.on("data", (data) => null);
    listener.stderr.on("data", (data) => null);
    listener.on("error", (error) =>
        console.log(`generate-index error: ${error.message}`),
    );
    listener.on("close", (code) => {
        console.log("A new index file has been generated.\n");
        // sync, one last time
        sync_all_data();
    });
}

/**
 * Resolve the PID of a running httrack process.
 * Catch the error if PID cannot be found.
 *
 * @returns {Promise<boolean|*>}
 */
async function process_is_running(process) {
    try {
        return execSync("pgrep " + process);
    } catch (error) {
        return false;
    }
}

/**
 * Creates system directory[s] from the given path.
 *
 * This function supports parent path creation using linux `mkdir -p`. Therefore, it is possible to pass any
 * string to this path that `mkdir` supports: https://linux.die.net/man/1/mkdir
 *
 * @param directory string
 */
function mkdir(directory) {
    exec("mkdir -p " + directory, (error, stdout, stderr) => {
        if (error) {
            console.error(`exec error: ${error}`);
            return;
        }
        console.log(stdout);
    });
}

app.listen(port);
