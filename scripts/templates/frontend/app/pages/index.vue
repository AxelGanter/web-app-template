<template>
  <main class="home-page">
    <section class="home-card">
      <p class="home-eyebrow">Authenticated SPA scaffold</p>
      <h1>{{ user?.name || 'Signed in' }}</h1>
      <p>{{ user?.email }}</p>
      <div class="home-actions">
        <button type="button" :disabled="loading" @click="signOut">
          {{ loading ? 'Signing out…' : 'Sign out' }}
        </button>
      </div>
    </section>
  </main>
</template>

<script setup lang="ts">
const { user, logout } = useAuth()
const router = useRouter()
const loading = ref(false)

async function signOut() {
  if (loading.value) return
  loading.value = true
  try {
    await logout()
    await router.push('/login')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.home-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  background: #fafaf9;
  color: #1c1917;
}

.home-card {
  width: min(720px, calc(100vw - 32px));
  padding: 32px;
  border-radius: 16px;
  border: 1px solid #d6d3d1;
  background: #fff;
}

.home-eyebrow {
  margin: 0 0 8px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-size: 0.75rem;
  color: #78716c;
}

.home-card h1,
.home-card p {
  margin: 0 0 8px;
}

.home-actions {
  margin-top: 18px;
}

.home-actions button {
  padding: 10px 14px;
  border: 0;
  border-radius: 8px;
  background: #1c1917;
  color: #fff;
  font: inherit;
  cursor: pointer;
}
</style>
