((window) => {
  const {
    screen: { width, height },
    navigator: { language },
    location,
    document,
    history,
    top,
  } = window;
  const { currentScript, referrer } = document;
  if (!currentScript) return;

  const { hostname, href, origin } = location;
  const localStorage = href.startsWith("data:") ? undefined : window.localStorage;

  const VERSION = "1";

  const attr = currentScript.getAttribute.bind(currentScript);

  const website = attr("data-website-id");
  if (!website) return;

  const hostUrl = "https://reops-event-proxy.ekstern.dev.nav.no";
  const beforeSend = attr("data-before-send");
  const autoTrack = attr("data-auto-track") !== "false";
  const domain = attr("data-domains") || "";
  const optOutFilters = attr("data-opt-out-filters") || undefined;

  const domains = domain.split(",").map((n) => n.trim());

  const endpoint = `${hostUrl.replace(/\/$/, "")}/api/send`;
  const screen = `${width}x${height}`;
  const eventRegex = /data-umami-event-([\w-_]+)/;
  const eventNameAttribute = "data-umami-event";

  /* UUID redaction */

  const redactUuid = (s) => s;

  /* Helper functions */

  const normalize = (raw) => {
    if (!raw) return raw;
    try {
      return redactUuid(new URL(raw, location.href).toString());
    } catch {
      return raw;
    }
  };

  const getPayload = () => ({
    website,
    screen,
    language,
    title: redactUuid(document.title),
    hostname,
    url: currentUrl,
    referrer: currentRef,
    id: identity || undefined,
  });

  /* Event handlers */

  const handlePush = (_state, _title, url) => {
    if (!url) return;

    currentRef = currentUrl;
    currentUrl = normalize(new URL(url, location.href).toString());

    if (currentUrl !== currentRef) {
      setTimeout(track, 300);
    }
  };

  const handlePathChanges = () => {
    const hook = (_this, method, callback) => {
      const orig = _this[method];
      return (...args) => {
        callback.apply(null, args);
        return orig.apply(_this, args);
      };
    };

    history.pushState = hook(history, "pushState", handlePush);
    history.replaceState = hook(history, "replaceState", handlePush);
  };

  const handleClicks = () => {
    const trackElement = async (el) => {
      const eventName = el.getAttribute(eventNameAttribute);
      if (eventName) {
        const eventData = {};

        el.getAttributeNames().forEach((name) => {
          const match = name.match(eventRegex);
          if (match) eventData[match[1]] = el.getAttribute(name);
        });

        return track(eventName, eventData);
      }
    };
    const onClick = async (e) => {
      const el = e.target;
      const parentElement = el.closest("a,button");
      if (!parentElement) return trackElement(el);

      const { href, target } = parentElement;
      if (!parentElement.getAttribute(eventNameAttribute)) return;

      if (parentElement.tagName === "BUTTON") {
        return trackElement(parentElement);
      }
      if (parentElement.tagName === "A" && href) {
        const external =
          target === "_blank" ||
          e.ctrlKey ||
          e.shiftKey ||
          e.metaKey ||
          (e.button && e.button === 1);
        if (!external) e.preventDefault();
        return trackElement(parentElement).then(() => {
          if (!external) {
            (target === "_top" ? top.location : location).href = href;
          }
        });
      }
    };
    document.addEventListener("click", onClick, true);
  };

  /* Tracking functions */

  const trackingDisabled = () =>
    !website ||
    localStorage?.getItem("umami.disabled") ||
    (domain && !domains.includes(hostname));

  const send = async (payload, type = "event") => {
    if (trackingDisabled()) return;
    const callback = window[beforeSend];

    if (typeof callback === "function") {
      payload = await Promise.resolve(callback(type, payload));
    }

    if (!payload) return;

    try {
      await fetch(endpoint, {
        keepalive: true,
        method: "POST",
        body: JSON.stringify({ type, payload }),
        headers: {
          "Content-Type": "application/json",
          "X-Script-Version": VERSION,
          ...(optOutFilters && { "x-opt-out-filters": optOutFilters }),
        },
        credentials: "omit",
      });
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
    } catch (_e) {
      /* no-op */
    }
  };

  const init = () => {
    if (!initialized) {
      initialized = true;
      track();
      handlePathChanges();
      handleClicks();
    }
  };

  const track = (name, data) => {
    if (typeof name === "string") return send({ ...getPayload(), name, data });
    if (typeof name === "object") return send({ ...name });
    if (typeof name === "function") return send(name(getPayload()));
    return send(getPayload());
  };

  const identify = (id, data) => {
    if (typeof id === "string") {
      identity = id;
    }

    return send(
      {
        ...getPayload(),
        data: typeof id === "object" ? id : data,
      },
      "identify",
    );
  };

  /* Start */

  if (!window.umami) {
    window.umami = {
      track,
      identify,
    };
  }

  let currentUrl = normalize(href);
  let currentRef = normalize(referrer.startsWith(origin) ? "" : referrer);

  let initialized = false;
  let identity;

  if (autoTrack && !trackingDisabled()) {
    if (document.readyState === "complete") {
      init();
    } else {
      document.addEventListener("readystatechange", init, true);
    }
  }
})(window);
