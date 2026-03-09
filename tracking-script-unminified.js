// Unminified version of your tracking script
(function() {
  "use strict";
  
  ((window) => {
    const {
      screen: { width, height },
      navigator: { language, doNotTrack: ndnt, msDoNotTrack: msdnt },
      location,
      document,
      history,
      top,
      doNotTrack,
    } = window;
    
    const { currentScript, referrer } = document;
    if (!currentScript) return;

    const { hostname, href, origin } = location;
    const localStorage = href.startsWith("data:") ? undefined : window.localStorage;

    const _data = "data-";
    const _true = "true";
    const attr = currentScript.getAttribute.bind(currentScript);
    
    const website = attr(_data + "website-id");
    const hostUrl = attr(_data + "host-url");
    const beforeSend = attr(_data + "before-send");
    const tag = attr(_data + "tag") || undefined;
    const autoTrack = "false" !== attr(_data + "auto-track");
    const dnt = attr(_data + "do-not-track") === _true;
    const excludeSearch = attr(_data + "exclude-search") === _true;
    const excludeHash = attr(_data + "exclude-hash") === _true;
    const domain = attr(_data + "domains") || "";
    
    const domains = domain.split(",").map(n => n.trim());
    const endpoint = `${(hostUrl || "" || currentScript.src.split("/").slice(0, -1).join("/")).replace(/\/$/, "")}/api/send`;
    const screen = `${width}x${height}`;
    const eventRegex = /data-umami-event-([\w-_]+)/;
    const eventNameAttribute = _data + "umami-event";
    const delayDuration = 300;

    /* Helper functions */
    
    const getPayload = () => ({
      website: website,
      screen: screen,
      language: language,
      title: document.title,
      hostname: hostname,
      url: currentUrl,
      referrer: currentRef,
      tag: tag,
      id: identity || undefined
    });

    const handlePush = (state, title, url) => {
      if (url) {
        currentRef = currentUrl;
        currentUrl = new URL(url, location.href);
        
        if (excludeSearch) {
          currentUrl.search = "";
        }
        if (excludeHash) {
          currentUrl.hash = "";
        }
        
        currentUrl = currentUrl.toString();
        
        if (currentUrl !== currentRef) {
          setTimeout(track, delayDuration);
        }
      }
    };

    const trackingDisabled = () => 
      disabled || 
      !website || 
      localStorage && localStorage.getItem("umami.disabled") || 
      domain && !domains.includes(hostname) || 
      dnt && ((() => {
        const dnt = doNotTrack || ndnt || msdnt;
        return dnt === 1 || dnt === "1" || dnt === "yes";
      })());

    const send = async (payload, type = "event") => {
      if (trackingDisabled()) return;

      const callback = window[beforeSend];
      if (typeof callback === "function") {
        payload = callback(type, payload);
      }

      if (payload) {
        try {
          const res = await fetch(endpoint, {
            method: "POST",
            body: JSON.stringify({ type: type, payload: payload }),
            headers: {
              "Content-Type": "application/json",
              ...(undefined !== cache && { "x-umami-cache": cache })
            },
            credentials: "omit"
          });
          
          const data = await res.json();
          if (data) {
            disabled = !!data.disabled;
            cache = data.cache;
          }
        } catch (e) {
          // no-op
        }
      }
    };

    const init = () => {
      if (!initialized) {
        initialized = true;
        track();
        
        // Handle path changes
        (() => {
          const hook = (obj, method, callback) => {
            const orig = obj[method];
            return (...args) => {
              callback.apply(null, args);
              return orig.apply(obj, args);
            };
          };
          history.pushState = hook(history, "pushState", handlePush);
          history.replaceState = hook(history, "replaceState", handlePush);
        })();
        
        // Handle clicks
        (() => {
          const trackElement = async (el) => {
            const eventName = el.getAttribute(eventNameAttribute);
            if (eventName) {
              const eventData = {};
              el.getAttributeNames().forEach(name => {
                const match = name.match(eventRegex);
                if (match) {
                  eventData[match[1]] = el.getAttribute(name);
                }
              });
              return track(eventName, eventData);
            }
          };
          
          document.addEventListener("click", async (e) => {
            const target = e.target;
            const parentElement = target.closest("a,button");
            
            if (!parentElement) {
              return trackElement(target);
            }
            
            const { href, target: linkTarget } = parentElement;
            
            if (parentElement.getAttribute(eventNameAttribute)) {
              if ("BUTTON" === parentElement.tagName) {
                return trackElement(parentElement);
              }
              
              if ("A" === parentElement.tagName && href) {
                const external = 
                  "_blank" === linkTarget || 
                  e.ctrlKey || 
                  e.shiftKey || 
                  e.metaKey || 
                  e.button && 1 === e.button;
                
                if (!external) {
                  e.preventDefault();
                }
                
                return trackElement(parentElement).then(() => {
                  if (!external) {
                    (("_top" === linkTarget ? top.location : location).href = href);
                  }
                });
              }
            }
          }, true);
        })();
      }
    };

    const track = (name, data) => {
      if (typeof name === "string") {
        return send({ ...getPayload(), name: name, data: data });
      }
      if (typeof name === "object") {
        return send({ ...name });
      }
      if (typeof name === "function") {
        return send(name(getPayload()));
      }
      return send(getPayload());
    };

    const identify = (id, data) => {
      if (typeof id === "string") {
        identity = id;
      }
      cache = "";
      return send({
        ...getPayload(),
        data: typeof id === "object" ? id : data
      }, "identify");
    };

    /* Start */
    
    if (!window.umami) {
      window.umami = { track: track, identify: identify };
    }

    let cache;
    let identity;
    let currentUrl = href;
    let currentRef = referrer.startsWith(origin) ? "" : referrer;
    let initialized = false;
    let disabled = false;

    if (autoTrack && !trackingDisabled()) {
      if ("complete" === document.readyState) {
        init();
      } else {
        document.addEventListener("readystatechange", init, true);
      }
    }
  })(window);
})();
