export default defineNuxtRouteMiddleware(async (to) => {
  if (to.path === '/login') return

  const { user, initialize } = useAuth()
  await initialize()

  if (!user.value) return navigateTo('/login')
})
