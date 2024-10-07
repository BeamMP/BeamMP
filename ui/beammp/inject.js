// Experimental Vue Inject for BeamMP
// Use the following from the CEF Dev tools window to load this file:
// var script = document.createElement('script'); script.src="local://local/ui/beammp/inject.js"; document.head.appendChild(script);

var pages = [
  {src: 'pages/login.js', instance: 'Login', ref: 'beammp_Login'}
]

window.beammp = {
  pages: {}
}

function loadPageScript(src, callback) {
  const script = document.createElement('script');
  script.src = `local://local/ui/beammp/${src}`;
  script.onload = callback;
  script.onerror = function() {
    console.error(`Error loading ${src}`);
  };
  document.head.appendChild(script);
}

var vueApp = document.querySelector('#vue-app').__vue_app__;
var router = vueApp._context.config.globalProperties.$router


if (vueApp && router) {

  if (router) {
    console.log('Vue Router found:', router);
    console.log('Current route:', router.currentRoute.value);

    // Inject BeamMP Routes
    pages.forEach(function (page) {
      loadPageScript(page.src, function() {
        console.log(`${page.src} component loaded`)
        vueApp._context.app.component(page.ref, window.beammp.pages[page.instance])
        router.addRoute({ path: '/login', component: window.beammp.pages[page.instance] });
      })
    })
  } else {
    console.error('Vue Router not found.');
  }

  
  router.push('/mainmenu');
}

console.log('BeamMP Injected :)')




// Component inject & render test
/*
// Define a new Vue component for the User Profile Chip
const UserProfileChip = {
  props: ['username', 'role', 'avatarUrl'],
  template: `
    <div class="profile-chip">
      <img :src="avatarUrl || 'https://via.placeholder.com/50'" alt="User Avatar" class="avatar">
      <div class="profile-details">
        <div class="username">{{ username }}</div>
        <div class="role" :class="roleClass">{{ role }}</div>
      </div>
    </div>
  `,
  computed: {
    // Compute the role-specific class for dynamic styling
    roleClass() {
      switch (this.role.toLowerCase()) {
        case 'player':
          return 'player';
        case 'guest':
          return 'guest';
        case 'beammp staff':
        case 'staff':
          return 'staff';
        case 'early access':
          return 'early-access';
        case 'beamng staff':
          return 'beamng-staff';
        default:
          return '';
      }
    }
  },
  mounted() {
    console.log(`UserProfileChip mounted for ${this.username}`);
  }
};

// Add the component to the Vue app
vueApp._context.app.component('user-profile-chip', UserProfileChip);


// Apply styles using CSS
const style = document.createElement('style');
style.textContent = `
  .profile-chip {
    display: flex;
    align-items: center;
    background: rgba(255, 255, 255, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 50px;
    padding: 10px 15px;
    backdrop-filter: blur(10px);
    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
    transition: all 0.3s ease;
    color: #fff;
    font-family: Arial, sans-serif;
  }

  .profile-chip:hover {
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.15);
  }

  .profile-chip .avatar {
    width: 50px;
    height: 50px;
    border-radius: 50%;
    object-fit: cover;
    margin-right: 15px;
  }

  .profile-chip .username {
    font-size: 1.1rem;
    font-weight: bold;
  }

  .profile-chip .role {
    font-size: 0.9rem;
    opacity: 0.8;
  }

  .profile-chip .role.player {
    color: #76b900;
  }

  .profile-chip .role.guest {
    color: #ff4f4f;
  }

  .profile-chip .role.staff {
    color: #1f8ef1;
  }

  .profile-chip .role.early-access {
    color: #ffcc00;
  }

  .profile-chip .role.beamng-staff {
    color: #ff6f00;
  }
`;

// Append the style to the document head
document.head.appendChild(style);

setTimeout(() => {
  // Sample user data for the card
  const sampleUserData = {
    username: 'JohnDoe',
    avatar: 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y', // Placeholder avatar URL
    role: 'Guest'
  };

  // Dynamically create a new instance of the UserProfileChip
  const userProfileCardElement = document.createElement('div');
  console.log(userProfileCardElement)
  document.getElementById('user-profile-container').appendChild(userProfileCardElement);


  // Create and mount the UserProfileChip component instance
  const userProfileCardInstance = vueApp._context.app.mount(userProfileCardElement, {
    components: { UserProfileChip },
    data() {
      return {
        username: sampleUserData.username,
        avatar: sampleUserData.avatar,
        role: sampleUserData.role
      };
    },
    template: '<user-profile-card :username="username" :avatar="avatar" :role="role" />'
  });
  console.log(userProfileCardInstance)
}, 500); // Delay for a short time to allow Vue to render the HelloWorld page
*/