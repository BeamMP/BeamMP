<template>
  <section class="login-layout">
    <article class="login-popup">
      <img :src="logoSrc" class="beammp-logo" alt="BeamMP" @error="onLogoError" />

      <p v-if="state.loginError.value" class="error">{{ state.loginError.value }}</p>

      <template v-if="mode === 'account'">
        <h2 class="login-title">{{ $tt("ui.beammp.accounts.loginDescription1") }}</h2>

        <div class="input-group">
          <label for="beammp-login-username">{{ $tt("ui.beammp.login.username") }}</label>
          <div class="input-shell">
            <span class="field-prefix" aria-hidden="true">@</span>
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
          <label for="beammp-login-password">{{ $tt("ui.beammp.login.password") }}</label>
          <div class="input-shell">
            <span class="field-prefix password-prefix" aria-hidden="true">•••</span>
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
          <BngButton @click="submitLogin">{{ $tt("ui.beammp.login") }}</BngButton>
          <BngButton accent="secondary" @click="register">{{ $tt("ui.beammp.register") }}</BngButton>
          <BngButton accent="secondary" @click="switchToGuest">{{ $tt("ui.beammp.accounts.playAsGuest") }}</BngButton>
        </div>
      </template>

      <template v-else>
        <p class="guest-copy">{{ $tt("ui.beammp.accounts.guestDescription1") }}</p>
        <div class="actions">
          <!--<BngButton @click="switchToAccount">{{ $tt("ui.beammp.accounts.iHaveAnAccount") }}</BngButton>-->
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
const mode = ref("guest")
const LEGACY_LOGO_PATH = "local://local/ui/modModulesOLD/multiplayer/beammp_new_cropped.png"
const LOGO_FALLBACK = "/ui/ui-vue/mods/BeamMP/icons/account-multiple.svg"
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
  password.value = ""
}

async function submitGuest() {
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
  display: grid;
  place-items: center;
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
  color: var(--bng-red-500);
}

@media (max-width: 680px) {
  .actions {
    > * {
      flex: 1 1 100%;
    }
  }
}
</style>
