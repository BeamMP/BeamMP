<template>
  <section class="login-layout">
    <div class="info-banner">
      <svg class="banner-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
        <path d="M12 16V12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
        <circle cx="12" cy="8" r="1" fill="currentColor"/>
      </svg>
      <div class="banner-text">
        <p>The new accounts system is currently being tested by our <a href="#" @click.prevent="openExternal('https://www.patreon.com/BeamMP')" class="ea-link">Early Access Supporters</a>. It will become available to everyone once testing is concluded. Please use a guest account in the meantime. Visit our <a href="#" @click.prevent="openExternal('https://discord.gg/beammp')" class="discord-link">Discord</a> for the latest updates.</p>
      </div>
      <BngButton class="read-more-button" accent="secondary" @click="showReadMorePopup = true">
        Read More
      </BngButton>
    </div>

    <div v-if="showReadMorePopup" class="popup-overlay" @click.self="showReadMorePopup = false">
      <div class="popup-content">
        <h3>Account Information</h3>
        <p>Are you an Early Access Supporter who previously had an account? Please read this <a href="#" @click.prevent="openExternal('https://www.patreon.com/BeamMP/posts/moment-youve-all-169326895')" class="popup-link">Patreon post</a> for more information on how to recover your account.</p>
        <p>Are you an Early Access Supporter but don't have an account yet, or are you having issues with account recovery or login? Please make an Account Support ticket in <code># ❔️ Support</code> in our <a href="#" @click.prevent="openExternal('https://discord.gg/beammp')" class="popup-link">Discord server</a></p>
        <BngButton class="popup-close-button" @click="showReadMorePopup = false">Close</BngButton>
      </div>
    </div>
    <article class="login-popup">
      <img :src="logoSrc" class="beammp-logo" alt="BeamMP" @error="onLogoError" />

      <p v-if="state.loginError.value && hasTriedToLogin" class="error">{{ state.loginError.value }}</p>

      <template v-if="mode === 'account'">
        <h2 class="login-title">{{ $tt("ui.beammp.accounts.loginDescription1") }}</h2>

        <div class="input-group">
          <label for="beammp-login-username">{{ $tt("ui.beammp.accounts.login.username") }}</label>
          <div class="input-shell">
            <input
              id="beammp-login-username"
              v-model="username"
              v-bng-text-input
              type="text"
              autocomplete="username"
              autocapitalize="none"
              spellcheck="false"
            />
          </div>
        </div>

        <div class="input-group">
          <label for="beammp-login-password">{{ $tt("ui.beammp.accounts.login.password") }}</label>
          <div class="input-shell">
            <input
              id="beammp-login-password"
              v-model="password"
              v-bng-text-input
              type="password"
              autocomplete="current-password"
              @keyup.enter="submitLogin"
            />
          </div>
        </div>

        <div class="actions">
          <BngButton @click="submitLogin">{{ $tt("ui.beammp.accounts.login") }}</BngButton>
          <BngButton accent="secondary" @click="submitGuest">{{ $tt("ui.beammp.accounts.playAsGuest") }}</BngButton>
        </div>
      </template>

      <template v-else>
        <p class="guest-copy">{{ $tt("ui.beammp.accounts.guestDescription1") }}</p>
        <div class="actions">
          <BngButton @click="switchToAccount">{{ $tt("ui.beammp.accounts.iHaveAnAccount") }}</BngButton>
          <BngButton accent="secondary" @click="submitGuest">{{ $tt("ui.beammp.accounts.playAsGuest") }}</BngButton>
        </div>
      </template>
    </article>
  </section>
</template>

<script setup>
import { ref, watch } from "vue"
import { useRouter } from "vue-router"
import { BngButton } from "@/common/components/base"
import { vBngTextInput } from "@/common/directives"
import { BEAMMP_SERVERS_ROUTE_NAME } from "../shared/constants.js"
import { useBeamMPState } from "../shared/beammpState.js"

const router = useRouter()
const username = ref("")
const password = ref("")
const hasTriedToLogin = ref(false)
const mode = ref("account")
const showReadMorePopup = ref(false)
const LEGACY_LOGO_PATH = "ui/assets/BeamMP/beammp_new_cropped.png"
const LOGO_FALLBACK = "/ui/assets/BeamMP/icons/account-multiple.svg"
const logoSrc = ref(LEGACY_LOGO_PATH)
const { login, guestLogin, openExternal, state } = useBeamMPState()

function onLogoError() {
  if (logoSrc.value !== LOGO_FALLBACK) {
    logoSrc.value = LOGO_FALLBACK
  }
}

function switchToGuest() {
  mode.value = "guest"
}

function switchToAccount() {
  mode.value = "account"
}

async function submitLogin() {
  await login(username.value, password.value)
  hasTriedToLogin.value = true
  password.value = ""
}

async function submitGuest() {
  hasTriedToLogin.value = true
  await guestLogin()
}

function register() {
  openExternal("https://forum.beammp.com/signup")
}

watch(() => state.loggedIn.value, value => {
  if (value) router.replace({ name: BEAMMP_SERVERS_ROUTE_NAME })
}, { immediate: true })
</script>

<style scoped lang="scss">
.login-layout {
  min-height: min(40rem, 70vh);
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 0;
  margin: 0;
  overflow: hidden;
  position: relative;
}

.info-banner {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1.5rem;
  border: 1px solid rgba(var(--bng-orange-400-rgb), 0.5);
  border-radius: 0 0 var(--bng-corners-2) var(--bng-corners-2);
  background: rgba(var(--bng-orange-500-rgb), 0.15);
  width: 100%;
  max-width: 100%;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  box-sizing: border-box;
  flex-shrink: 0;
  margin: 0;
}

.banner-icon {
  flex: 0 0 auto;
  width: 1.5rem;
  height: 1.5rem;
  color: var(--bng-off-white);
}

.read-more-button {
  flex: 0 0 auto;
  font-size: 0.85rem;
  padding: 0.4rem 0.8rem;
  min-height: 2rem;
}

.banner-text {
  margin: 0;
  font-size: 0.95rem;
  line-height: 1.5;
  color: var(--bng-off-white);
  flex: 1;

  p {
    margin: 0;
  }

  strong {
    font-weight: 700;
    color: var(--bng-orange-400);
  }

  .ea-link,
  .discord-link,
  .popup-link {
    color: rgb(193, 139, 255);
    text-decoration: none;
    font-weight: 600;
    cursor: pointer;
    transition: color 120ms ease;

    &:hover {
      color: rgb(213, 159, 255);
      text-decoration: underline;
    }
  }

  .discord-link {
    color: rgb(114, 137, 218);

    &:hover {
      color: rgb(134, 157, 238);
    }
  }

  code {
    padding: 0.1rem 0.3rem;
    border-radius: 0.2rem;
    background: rgba(0, 0, 0, 0.3);
    font-family: monospace;
    color: var(--bng-off-white);
  }
}

.login-popup {
  width: min(36rem, 96%);
  padding: 1rem;
  border-radius: var(--bng-corners-3);
  border: 2px solid rgba(var(--bng-cool-gray-600-rgb), 0.95);
  background: linear-gradient(145deg, rgba(29, 29, 29, 0.92), rgba(20, 20, 20, 0.9));
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
  color: var(--bng-off-white);
}

.beammp-logo {
  width: auto;
  max-width: 14rem;
  height: 4rem;
  object-fit: contain;
  margin: 0 auto 0.25rem;
}

.login-title {
  margin: 0;
  text-align: center;
  font-weight: 700;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;

  label {
    font-size: 0.85rem;
    font-weight: 600;
    color: var(--bng-cool-gray-100);
  }
}

.input-shell {
  display: flex;
  min-height: 2.7rem;
  align-items: stretch;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.22);
  border-radius: var(--bng-corners-1);
  background: rgba(7, 10, 14, 0.78);
  transition: border-color 120ms ease, box-shadow 120ms ease;

  &:hover {
    border-color: rgba(255, 255, 255, 0.42);
  }

  &:focus-within {
    border-color: var(--bng-orange-500);
    box-shadow: 0 0 0 0.13rem rgba(var(--bng-orange-500-rgb), 0.32);
  }

  input {
    flex: 1;
    min-width: 0;
    padding: 0.55rem 0.7rem;
    border: 0;
    outline: 0;
    color: var(--bng-off-white);
    background: transparent;
    font: inherit;

    &:-webkit-autofill {
      -webkit-text-fill-color: var(--bng-off-white);
      box-shadow: 0 0 0 1000px rgb(12, 15, 20) inset;
    }
  }
}

.field-prefix {
  display: grid;
  min-width: 2.6rem;
  place-items: center;
  padding: 0 0.5rem;
  border-right: 1px solid rgba(255, 255, 255, 0.14);
  color: var(--bng-cool-gray-200);
  background: rgba(255, 255, 255, 0.07);
  font-size: 0.82rem;
  font-weight: 700;
}

.password-prefix {
  letter-spacing: 0.08rem;
}

.guest-copy {
  color: var(--bng-cool-gray-100);
  margin: 0;
}

.actions {
  justify-content: center;
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;

  :deep(button),
  :deep(.bng-button) {
    margin: 0;
  }
}

.error {
  margin: 0;
  text-align: center;
  color: var(--bng-add-red-500);
}

@media (max-width: 900px) {
  .info-banner {
    flex-direction: column;
    text-align: center;
    padding: 0.75rem 1rem;
    gap: 0.5rem;
  }

  .banner-text {
    font-size: 0.85rem;
  }

  .read-more-button {
    align-self: center;
  }
}

@media (max-width: 680px) {
  .actions {
    > * {
      flex: 1 1 100%;
    }
  }
}

.popup-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.8);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.popup-content {
  background: linear-gradient(145deg, rgba(32, 32, 36, 0.98), rgba(24, 24, 28, 0.98));
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: var(--bng-corners-3);
  padding: 2rem;
  max-width: 45rem;
  width: 100%;
  color: var(--bng-off-white);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6), 0 0 0 1px rgba(255, 255, 255, 0.05);
  overflow-wrap: break-word;
  word-wrap: break-word;
  word-break: break-word;

  h3 {
    margin: 0 0 1.25rem;
    color: var(--bng-orange-400);
    font-size: 1.25rem;
    font-weight: 700;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    padding-bottom: 0.75rem;
  }

  p {
    margin: 0 0 1.25rem;
    line-height: 1.7;
    color: var(--bng-cool-gray-100);
    font-size: 0.95rem;
    overflow-wrap: break-word;
    word-wrap: break-word;
    word-break: break-word;
  }

  p:last-of-type {
    margin-bottom: 1.5rem;
  }

  code {
    padding: 0.15rem 0.4rem;
    border-radius: 0.25rem;
    background: rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.1);
    font-family: 'Consolas', 'Monaco', monospace;
    font-size: 0.9rem;
    color: var(--bng-orange-300);
  }

  .popup-link {
    color: rgb(114, 137, 218);
    text-decoration: none;
    font-weight: 600;
    cursor: pointer;
    transition: color 120ms ease;

    &:hover {
      color: rgb(134, 157, 238);
      text-decoration: underline;
    }
  }
}

.popup-close-button {
  margin-top: 1rem;
  padding: 0.6rem 1.5rem;
  font-weight: 600;
  min-width: 6rem;
}
</style>
