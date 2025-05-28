// Main scroll-triggered animations
function initScrollAnimations() {
	const observerOptions = {
		threshold: 0.1,
		rootMargin: '0px 0px -50px 0px'
	};

	const observer = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				entry.target.classList.add('revealed');
			}
		});
	}, observerOptions);

	document.querySelectorAll('.scroll-reveal, .scroll-reveal-left, .scroll-reveal-right').forEach(el => {
		observer.observe(el);
	});
}

// Project cards staggered animation
function initProjectCardAnimations() {
	const projectCards = document.querySelectorAll('.project-card');

	const projectObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');

					// Animate card elements
					const projectTitle = entry.target.querySelector('.project-title');
					const projectDescription = entry.target.querySelector('.project-description');
					const projectLinks = entry.target.querySelector('.project-links');
					const techTags = entry.target.querySelectorAll('.tech-tag');

					if (projectTitle) {
						setTimeout(() => projectTitle.classList.add('animate'), 100);
					}
					if (projectDescription) {
						setTimeout(() => projectDescription.classList.add('animate'), 200);
					}
					if (projectLinks) {
						setTimeout(() => projectLinks.classList.add('animate'), 400);
					}

					// Animate tech tags
					techTags.forEach((tag, i) => {
						setTimeout(() => {
							tag.classList.add('animate');
						}, 300 + (i * 100));
					});
				}, index * 150);
			}
		});
	}, { threshold: 0.2 });

	projectCards.forEach(card => {
		projectObserver.observe(card);
	});
}

// Content stagger animation system
function initContentStagger() {
	const contentElements = document.querySelectorAll('.content-stagger');

	const contentObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 100);
			}
		});
	}, { threshold: 0.1 });

	contentElements.forEach(element => {
		contentObserver.observe(element);
	});
}

// Sidebar sections animation with proper stability
function initSidebarAnimations() {
	const sidebarSections = document.querySelectorAll('.sidebar-section');

	const sidebarObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');

					// Animate tech tags in sidebar
					const techTags = entry.target.querySelectorAll('.tech-tag');
					techTags.forEach((tag, i) => {
						setTimeout(() => {
							tag.classList.add('animate');
						}, i * 50);
					});

					// Animate stat items
					const statItems = entry.target.querySelectorAll('.stat-item');
					statItems.forEach((item, i) => {
						setTimeout(() => {
							item.classList.add('animate');
						}, i * 100);
					});
				}, index * 200);
			}
		});
	}, { threshold: 0.3 });

	sidebarSections.forEach(section => {
		sidebarObserver.observe(section);
	});
}

// Animated counters for stats
function initStatCounters() {
	const statNumbers = document.querySelectorAll('.stat-number');

	const counterObserver = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				const target = parseInt(entry.target.getAttribute('data-count'));
				let current = 0;
				const increment = target / 50;
				const timer = setInterval(() => {
					current += increment;
					if (current >= target) {
						current = target;
						clearInterval(timer);
					}
					entry.target.textContent = Math.floor(current);
				}, 30);
			}
		});
	}, { threshold: 0.5 });

	statNumbers.forEach(number => {
		counterObserver.observe(number);
	});
}

// Enhanced 3D hover effects for project cards
function initProject3DEffects() {
	document.querySelectorAll('.project-card').forEach(card => {
		card.addEventListener('mousemove', (e) => {
			const rect = card.getBoundingClientRect();
			const x = e.clientX - rect.left;
			const y = e.clientY - rect.top;
			const centerX = rect.width / 2;
			const centerY = rect.height / 2;
			const deltaX = (x - centerX) / 20;
			const deltaY = (y - centerY) / 20;

			card.style.transform = `
				perspective(1000px)
				rotateX(${deltaY}deg)
				rotateY(${deltaX}deg)
				translateY(-15px)
				scale(1.03)
			`;
		});

		card.addEventListener('mouseleave', () => {
			card.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) translateY(0) scale(1)';
		});
	});
}

// Tech tag interactive effects
function initTechTagEffects() {
	document.querySelectorAll('.tech-tag').forEach(tag => {
		tag.addEventListener('click', function(e) {
			// Create ripple effect
			const ripple = document.createElement('span');
			const rect = this.getBoundingClientRect();
			const size = Math.max(rect.width, rect.height);
			const x = e.clientX - rect.left - size / 2;
			const y = e.clientY - rect.top - size / 2;

			ripple.style.cssText = `
				position: absolute;
				border-radius: 50%;
				background: rgba(255, 255, 255, 0.6);
				transform: scale(0);
				animation: ripple 0.6s linear;
				width: ${size}px;
				height: ${size}px;
				left: ${x}px;
				top: ${y}px;
				pointer-events: none;
			`;

			this.appendChild(ripple);

			setTimeout(() => {
				ripple.remove();
			}, 600);
		});
	});

	// Add ripple animation CSS
	if (!document.querySelector('#ripple-styles')) {
		const style = document.createElement('style');
		style.id = 'ripple-styles';
		style.textContent = `
			@keyframes ripple {
				to {
					transform: scale(4);
					opacity: 0;
				}
			}
		`;
		document.head.appendChild(style);
	}
}

// Project link button effects
function initProjectLinkEffects() {
	document.querySelectorAll('.project-link').forEach(link => {
		link.addEventListener('click', function(e) {
			// Add click animation
			this.style.transform = 'scale(0.95)';
			setTimeout(() => {
				this.style.transform = '';
			}, 150);
		});
	});
}

// Parallax scrolling effect for header
function initParallaxEffect() {
	window.addEventListener('scroll', () => {
		const scrolled = window.pageYOffset;
		const header = document.querySelector('.project-header');
		if (header) {
			header.style.transform = `translateY(${scrolled * 0.3}px)`;
		}
	});
}

// Enhanced navigation effects
function initNavigationEffects() {
	const navLinks = document.querySelectorAll('.nav-links a');
	navLinks.forEach(link => {
		link.addEventListener('mouseenter', function() {
			this.style.transform = 'translateY(-2px) scale(1.05)';
			this.style.boxShadow = '0 5px 15px rgba(255, 107, 107, 0.4)';
		});
		link.addEventListener('mouseleave', function() {
			if (!this.classList.contains('active')) {
				this.style.transform = 'translateY(0) scale(1)';
				this.style.boxShadow = '';
			}
		});
	});
}

// Project card loading simulation
function initProjectLoadingEffect() {
	const projectCards = document.querySelectorAll('.project-card');

	projectCards.forEach((card, index) => {
		card.classList.add('loading');

		setTimeout(() => {
			card.classList.remove('loading');
		}, 1000 + (index * 150));
	});
}

// Smooth page loading animation
function initPageLoadAnimation() {
	document.body.style.opacity = '0';
	document.body.style.transition = 'opacity 0.5s ease';

	setTimeout(() => {
		document.body.style.opacity = '1';
	}, 100);
}

// Initialize all animations when page loads
document.addEventListener('DOMContentLoaded', function() {
	initPageLoadAnimation();

	// Delay animation initialization for smooth loading
	setTimeout(() => {
		initScrollAnimations();
		initProjectCardAnimations();
		initContentStagger();
		initSidebarAnimations();
		initStatCounters();
		initProject3DEffects();
		initTechTagEffects();
		initProjectLinkEffects();
		initParallaxEffect();
		initNavigationEffects();
		// initProjectLoadingEffect(); // Uncomment for loading simulation

		// Add loaded class for final touches
		document.body.classList.add('animations-loaded');
	}, 150);
});

// Add smooth scrolling for anchor links
document.addEventListener('DOMContentLoaded', function() {
	document.querySelectorAll('a[href^="#"]').forEach(anchor => {
		anchor.addEventListener('click', function (e) {
			e.preventDefault();
			const target = document.querySelector(this.getAttribute('href'));
			if (target) {
				target.scrollIntoView({
					behavior: 'smooth',
					block: 'start'
				});
			}
		});
	});
});