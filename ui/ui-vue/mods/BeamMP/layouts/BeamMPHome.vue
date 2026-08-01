<template>
  <div class="beammp-home" v-bng-blur>
    <section class="hero card">
      <div class="hero-copy">
        <span class="eyebrow">{{ $tt('ui.common.beammp.beammp') }}</span>
        <h1>Multiplayer</h1>
        <p>
          Discover servers, catch up on the latest BeamMP news, and jump back into the community.
          This is the landing page for the BeamMP mod inside BeamNG's Vue UI.
        </p>

        <div class="hero-actions">
          <BngButton :accent="ACCENTS.custom_old" :icon-left="icons.globeSimple" @click="gotoServers">
            Server Browser
          </BngButton>
          <BngButton accent="secondary" :icon-left="icons.wrench" @click="gotoDirectConnect">
            Host / Direct Connect
          </BngButton>
        </div>
      </div>

      <div class="hero-stats">
        <div class="stat-card">
          <span>Players online</span>
          <strong>{{ state.beammpMetrics.value.players }}</strong>
        </div>
        <div class="stat-card">
          <span>Servers online</span>
          <strong>{{ state.beammpMetrics.value.servers }}</strong>
        </div>
        <div class="stat-card featured">
          <span>Launcher build</span>
          <strong>{{ state.beammpMetrics.value.beammpLauncherVer }}</strong>
        </div>
      </div>
    </section>

    <section class="content-grid">
      <article class="card news-panel">
        <div class="section-head">
          <h2>News & Changelog</h2>
          <BngButton accent="secondary" @click="openDocs">Patch notes</BngButton>
        </div>

        <div class="feed-list">
          <div v-for="item in newsItems" :key="item.title" class="feed-item">
            <div class="feed-meta">
              <span class="feed-tag">{{ item.tag }}</span>
              <small>{{ item.date }}</small>
            </div>
            <strong>{{ item.title }}</strong>
            <p>{{ item.body }}</p>
          </div>
        </div>
      </article>

      <article class="card events-panel">
        <div class="section-head">
          <h2>Events</h2>
          <BngButton accent="secondary" @click="openForum">Community</BngButton>
        </div>

        <div class="event-list">
          <div v-for="event in events" :key="event.title" class="event-item">
            <span class="event-date">{{ event.date }}</span>
            <strong>{{ event.title }}</strong>
            <p>{{ event.body }}</p>
          </div>
        </div>
      </article>

      <article class="card links-panel">
        <div class="section-head">
          <h2>Quick Links</h2>
          <span class="quick-note">Jump straight in</span>
        </div>

        <div class="link-grid">
          <button class="quick-link" @click="gotoServers">
            <strong>Server Browser</strong>
            <span>Browse public, official, featured, and favorite servers.</span>
          </button>
          <button class="quick-link" @click="gotoTiles">
            <strong>Browse by Category</strong>
            <span>Use tiles and tags to narrow down what to play.</span>
          </button>
          <button class="quick-link" @click="gotoDirectConnect">
            <strong>Host or Join Direct</strong>
            <span>Enter an IP and port, or save a custom favorite.</span>
          </button>
          <button class="quick-link" @click="openDocs">
            <strong>Setup & Help</strong>
            <span>Read docs, rules, and troubleshooting guides.</span>
          </button>
        </div>
      </article>
    </section>
  </div>
</template>

<script setup>
import { useRouter } from "vue-router"
import { BngButton, ACCENTS, icons } from "@/common/components/base"
import { vBngBlur } from "@/common/directives"
import {
  BEAMMP_DIRECT_ROUTE_NAME,
  BEAMMP_SERVERS_ROUTE_NAME,
  BEAMMP_TILES_ROUTE_NAME,
} from "../shared/constants.js"
import { useBeamMPState } from "../shared/beammpState.js"

const router = useRouter()
const { openExternal, state } = useBeamMPState()

const newsItems = [
  {
    tag: "Release",
    date: "Latest",
    title: "BeamMP UI Home is now live",
    body: "The new homepage collects the most common multiplayer entry points into one place.",
  },
  {
    tag: "Changelog",
    date: "Today",
    title: "Vue migration in progress",
    body: "Legacy multiplayer screens are being rebuilt with reusable Vue layouts and state.",
  },
  {
    tag: "News",
    date: "Community",
    title: "Server browsing and hosting are highlighted",
    body: "Use the homepage to get directly into the browser, direct connect, or help docs.",
  },
]

const events = [
  {
    date: "Weekend",
    title: "Community cruise night",
    body: "Jump into freeroam servers and share screenshots with the BeamMP community.",
  },
  {
    date: "Weekly",
    title: "Server spotlight",
    body: "Featured and partner servers are surfaced here so they are easy to find.",
  },
]

function gotoServers() {
  router.push({ name: BEAMMP_SERVERS_ROUTE_NAME, params: { view: "" } })
}

function gotoTiles() {
  router.push({ name: BEAMMP_TILES_ROUTE_NAME })
}

function gotoDirectConnect() {
  router.push({ name: BEAMMP_DIRECT_ROUTE_NAME })
}

function openForum() {
  openExternal("https://forum.beammp.com")
}

function openDocs() {
  openExternal("https://docs.beammp.com")
}
</script>

<style scoped lang="scss">
.beammp-home {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  color: var(--bng-off-white);
}

.card {
  border: 1px solid rgba(var(--bng-orange-400-rgb), 0.28);
  border-radius: var(--bng-corners-2);
  background: rgba(0, 0, 0, 0.32);
  box-shadow: 0 1rem 2rem rgba(0, 0, 0, 0.22);
}

.hero {
  display: grid;
  grid-template-columns: minmax(0, 1.5fr) minmax(16rem, 0.85fr);
  gap: 1rem;
  padding: 1.1rem;
  background:
    radial-gradient(circle at top right, rgba(var(--bng-orange-500-rgb), 0.22), transparent 28%),
    linear-gradient(145deg, rgba(24, 24, 24, 0.95), rgba(14, 14, 14, 0.9));
}

.eyebrow {
  display: inline-flex;
  margin-bottom: 0.35rem;
  padding: 0.15rem 0.5rem;
  border-radius: 999px;
  background: rgba(var(--bng-orange-500-rgb), 0.2);
  color: var(--bng-orange-300);
  font-size: 0.75rem;
  text-transform: uppercase;
}

.hero-copy h1 {
  margin: 0;
  font-size: clamp(2rem, 4vw, 3.5rem);
  line-height: 1;
}

.hero-copy p {
  max-width: 52rem;
  margin: 0.75rem 0 0;
  color: var(--bng-cool-gray-100);
  line-height: 1.6;
}

.hero-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
  margin-top: 1rem;
}

.hero-stats {
  display: grid;
  gap: 0.6rem;
  align-content: start;
}

.stat-card {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.9rem;
  border-radius: var(--bng-corners-2);
  background: rgba(255, 255, 255, 0.06);

  span {
    color: var(--bng-cool-gray-200);
    font-size: 0.84rem;
  }

  strong {
    font-size: 1.8rem;
    line-height: 1;
  }
}

.stat-card.featured {
  background: linear-gradient(135deg, rgba(var(--bng-orange-500-rgb), 0.24), rgba(255, 255, 255, 0.05));
}

.content-grid {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  gap: 1rem;
}

.news-panel {
  grid-column: span 7;
  padding: 1rem;
}

.events-panel {
  grid-column: span 5;
  padding: 1rem;
}

.links-panel {
  grid-column: 1 / -1;
  padding: 1rem;
}

.section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.85rem;

  h2 {
    margin: 0;
    font-size: 1.2rem;
  }
}

.quick-note {
  color: var(--bng-cool-gray-300);
  font-size: 0.85rem;
}

.feed-list,
.event-list {
  display: grid;
  gap: 0.75rem;
}

.feed-item,
.event-item {
  padding: 0.8rem;
  border-radius: var(--bng-corners-1);
  background: rgba(255, 255, 255, 0.04);

  strong {
    display: block;
    margin-bottom: 0.25rem;
  }

  p {
    margin: 0;
    color: var(--bng-cool-gray-100);
    line-height: 1.5;
  }
}

.feed-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.45rem;
}

.feed-tag {
  display: inline-flex;
  padding: 0.14rem 0.45rem;
  border-radius: 999px;
  background: rgba(var(--bng-add-green-500-rgb), 0.18);
  color: var(--bng-add-green-200);
  font-size: 0.75rem;
  text-transform: uppercase;
}

.link-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.75rem;
}

.quick-link {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  min-height: 7.5rem;
  padding: 0.9rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: var(--bng-corners-2);
  background: linear-gradient(155deg, rgba(255, 255, 255, 0.05), rgba(0, 0, 0, 0.12));
  color: var(--bng-off-white);
  text-align: left;
  cursor: pointer;
  transition: transform 120ms ease, border-color 120ms ease, background-color 120ms ease;

  strong {
    font-size: 1rem;
  }

  span {
    color: var(--bng-cool-gray-200);
    line-height: 1.5;
  }

  &:hover,
  &:focus-visible {
    transform: translateY(-2px);
    border-color: rgba(var(--bng-orange-500-rgb), 0.75);
    background: linear-gradient(155deg, rgba(var(--bng-orange-500-rgb), 0.18), rgba(0, 0, 0, 0.2));
  }
}

@media (max-width: 1100px) {
  .hero,
  .content-grid {
    grid-template-columns: 1fr;
  }

  .news-panel,
  .events-panel,
  .links-panel {
    grid-column: auto;
  }

  .link-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 700px) {
  .link-grid {
    grid-template-columns: 1fr;
  }
}
</style>
